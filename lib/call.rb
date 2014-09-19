# -*- coding: us-ascii -*-
require 'securerandom'
require 'timeout'
require_relative './utils.rb'
require_relative './sources.rb'
require_relative './auth.rb'
require_relative './message.rb'
require_relative './sip_dialog.rb'

module Quaff
  class CSeq # :nodoc:
    attr_reader :num
    def initialize cseq_str
      @num, @method = cseq_str.split
      @num = @num.to_i
    end

    def increment
      @num = @num + 1
      to_s
    end

    def to_s
      "#{@num.to_s} #{@method}"
    end
  end

class Call
  attr_reader :cid

  def initialize(cxn,
                 cid,
                 my_uri,
                 target_uri,
                 destination=nil,
                 instance_id=nil)
    @cxn = cxn
    setdest(destination, recv_from_this: true) if destination
    @retrans = nil
    @t1, @t2 = 0.5, 32
    @instance_id = instance_id
    @dialog = SipDialog.new cid, my_uri, target_uri
    update_branch
  end

  # Changes the branch parameter if the Via header, creating a new transaction
  def update_branch via_hdr=nil
    via_hdr ||= get_new_via_hdr
    @last_Via = via_hdr
  end

  alias_method :new_transaction, :update_branch

  def get_new_via_hdr
    "SIP/2.0/#{@cxn.transport} #{Quaff::Utils.local_ip}:#{@cxn.local_port};rport;branch=#{Quaff::Utils::new_branch}"
  end

  def set_callee uri
    if /<(.*?)>/ =~ uri
      uri = $1
    end

    @dialog.target = uri
  end

  alias_method :set_dialog_target, :set_callee
  
  def create_dialog_from_request msg
    @dialog.established = true

    set_dialog_target msg.first_header("Contact")

    unless msg.all_headers("Record-Route").nil?
      @routeset = msg.all_headers("Record-Route")
    end

    @dialog.get_peer_info msg.header("From")
  end

  def create_dialog_from_response msg
    @dialog.established = true

    set_dialog_target msg.first_header("Contact")

    unless msg.all_headers("Record-Route").nil?
        @routeset = msg.all_headers("Record-Route").reverse
    end

    @dialog.get_peer_info msg.header("To")
  end

  # Sets the Source where messages in this call should be sent to by
  # default.
  #
  # Options:
  #    :recv_from_this - if true, also listens for any incoming
  #    messages over this source's connection. (This is only
  #    meaningful for connection-oriented transports.)
  def setdest source, options={}
    @src = source
    if options[:recv_from_this] and source.sock
      @cxn.add_sock source.sock
    end
  end

  def recv_request(method, dialog_creating=true)
    begin
      msg = recv_something
    rescue Timeout::Error
      raise "#{ @uri } timed out waiting for #{ method }"
    end

    unless msg.type == :request \
      and Regexp.new(method) =~ msg.method
      raise((msg.to_s || "Message is nil!"))
    end

    @dialog.cseq = CSeq.new(msg.header("CSeq")).num
    
    if dialog_creating
      create_dialog_from_request msg
    end
    msg
  end

  # Waits until the next message comes in, and handles it if it is one
  # of possible_messages.
  #
  # possible_messages is a list of things that can be received.
  # Elements can be:
  # * a string representing the SIP method, e.g. "INVITE"
  # * a number representing the SIP status code, e.g. 200
  # * a two-item list, containing one of the above and a boolean
  # value, which indicates whether this message is dialog-creating. by
  # default, requests are assumed to be dialog-creating and responses
  # are not.
  #
  # For example, ["INVITE", 301, ["ACK", false], [200, true]] is a
  # valid value for possible_messages.
  def recv_any_of(possible_messages)
    begin
      msg = recv_something
    rescue Timeout::Error
      raise "#{ @uri } timed out waiting for one of these: #{possible_messages}"
    end

    found_match = false
    dialog_creating = nil
    
    possible_messages.each do
      | what, this_dialog_creating |
      type = if (what.class == String) then :request else :response end
      if this_dialog_creating.nil?
        this_dialog_creating = (type == :request)
      end

      found_match =
        if type == :request 
          msg.type == :request and what == msg.method
        else
          msg.type == :response and what.to_s == msg.status_code
        end

      if found_match
        dialog_creating = this_dialog_creating
        break
      end
    end

    unless found_match
      raise((msg.to_s || "Message is nil!"))
    end

    if dialog_creating
      create_dialog msg
    end
    msg
  end

  def recv_response(code, dialog_creating=false)
    begin
      msg = recv_something
    rescue Timeout::Error
      raise "#{ @uri } timed out waiting for #{ code }"
    end
    unless msg.type == :response \
      and Regexp.new(code) =~ msg.status_code
      raise "Expected #{code}, got #{msg.status_code || msg}"
    end

    if dialog_creating
      create_dialog_from_response msg
    end

    msg
  end

  def recv_response_and_create_dialog(code)
    recv_response code, true
  end

  def send_response(code, phrase, body="", retrans=nil, headers={})
    method = nil
    msg = build_message headers, body, :response, method, code, phrase
    send_something(msg, retrans)
  end

  def send_request(method, body="", headers={})
    msg = build_message headers, body, :request, method
    send_something(msg, nil)
  end

  def end_call
    @cxn.mark_call_dead @dialog.call_id
  end

  def assoc_with_msg(msg)
    @last_Via = msg.all_headers("Via")
  end

  def get_next_hop header
    /<sip:(.+@)?(.+):(\d+);(.*)>/ =~ header
    sock = TCPSocket.new $2, $3
    return TCPSource.new sock
  end

  private
  def recv_something
    msg = @cxn.get_new_message @dialog.call_id
    @retrans = nil
    @src = msg.source
    @last_Via = msg.headers["Via"]
    @last_CSeq = CSeq.new(msg.header("CSeq"))
    msg
  end

  def calculate_cseq type, method
    if (type == :response)
      @last_CSeq.to_s
    else
      if (method != "ACK") and (method != "CANCEL")
        @dialog.cseq += 1
      end
      "#{@dialog.cseq} #{method}"
    end
  end

  def build_message headers, body, type, method=nil, code=nil, phrase=nil
    is_request = code.nil?

    defaults = {
      "Call-ID" => @dialog.call_id,
      "CSeq" => calculate_cseq(type, method),
      "Via" => @last_Via,
      "Max-Forwards" => "70",
      "Content-Length" => "0",
      "User-Agent" => "Quaff SIP Scripting Engine",
      "Contact" => @cxn.contact_header
    }

    if is_request
      defaults['From'] = @dialog.local_fromto
      defaults['To'] = @dialog.peer_fromto
      defaults['Route'] = @dialog.routeset
    else
      defaults['To'] = @dialog.local_fromto
      defaults['From'] = @dialog.peer_fromto
      defaults['Record-Route'] = @dialog.routeset
    end

    defaults.merge! headers

    SipMessage.new(method, code, phrase, @dialog.target, body, defaults.merge!(headers)).to_s
  end

  def send_something(msg, retrans)
    @cxn.send_msg(msg, @src)
    if retrans and (@transport == "UDP") then
      @retrans = true
      Thread.new do
        timer = @t1
        sleep timer
        while @retrans do
          #puts "Retransmitting on call #{ @dialog.call_id }"
          @cxn.send(msg, @src)
          timer *=2
          if timer < @t2 then
            raise "Too many retransmits!"
          end
          sleep timer
        end
      end
    end
  end

end
end
