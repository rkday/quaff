# -*- coding: us-ascii -*-
require_relative './utils.rb'
require_relative './sources.rb'
require_relative './auth.rb'
require_relative './message.rb'

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
                 instance_id=nil,
                 uri="sip:5557777888@#{Utils::local_ip}",
                 destination=nil,
                 target_uri=nil)
    @cxn = cxn
    @cseq_number = 1
    change_cid cid
    @uri = uri
    @retrans = nil
    @t1, @t2 = 0.5, 32
    @last_From = "<#{uri}>"
    update_branch
    @last_To = "<#{target_uri}>"
    setdest(destination, recv_from_this: true) if destination
    set_callee target_uri if target_uri
    @routeset = []
    @instance_id = instance_id
  end

  def change_cid cid
    @cid = cid
    @cxn.add_call_id @cid
  end

  def update_branch via_hdr=nil
    via_hdr ||= get_new_via_hdr
    @last_Via = via_hdr
  end

  alias_method :new_transaction, :update_branch

  def get_new_via_hdr
    "SIP/2.0/#{@cxn.transport} #{Quaff::Utils.local_ip}:#{@cxn.local_port};rport;branch=#{Quaff::Utils::new_branch}"
  end

  def create_dialog msg
    set_callee msg.first_header("Contact")
  end

  def set_callee uri
    if /<(.*?)>/ =~ uri
      uri = $1
    end

    @sip_destination = "#{uri}"
  end

  def setdest source, options={}
    @src = source
    if options[:recv_from_this] and source.sock
      @cxn.add_sock source.sock
    end
  end

  def recv_request(method, dialog_creating=true)
    begin
      msg = recv_something
    rescue
      raise "#{ @uri } timed out waiting for #{ method }"
    end
    unless msg.type == :request \
      and Regexp.new(method) =~ msg.method
      raise((msg.to_s || "Message is nil!"))
    end
    if dialog_creating
      set_callee msg.first_header("Contact")
      unless msg.all_headers("Record-Route").nil?
        @routeset = msg.all_headers("Record-Route")
      end
    end
    msg
  end

  def recv_response(code, dialog_creating=false)
    begin
      msg = recv_something
    rescue
      raise "#{ @uri } timed out waiting for #{ code }"
    end
    unless msg.type == :response \
      and Regexp.new(code) =~ msg.status_code
      raise "Expected #{ code}, got #{msg.status_code || msg}"
    end
    if dialog_creating
      set_callee msg.first_header("Contact")
      unless msg.all_headers("Record-Route").nil?
        @routeset = msg.all_headers("Record-Route").reverse
      end
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
    @cxn.mark_call_dead @cid
  end

  def clear_tag str
    str
  end

  def assoc_with_msg(msg)
    @last_Via = msg.all_headers("Via")
    @last_CSeq = CSeq.new(msg.header("CSeq"))
  end

  def clone_details other_message
    @headers['To'] = [clear_tag(other_message.header("To"))]
    @headers['From'] = [clear_tag(other_message.header("From"))]
    @headers['Route'] = [other_message.header("Route")]
  end

  def get_next_hop header
    /<sip:(.+@)?(.+):(\d+);(.*)>/ =~ header
    sock = TCPSocket.new $2, $3
    return TCPSource.new sock
  end

  private
  def recv_something
    msg = @cxn.get_new_message @cid
    @retrans = nil
    @src = msg.source
    @last_To = msg.header("To")
    @last_From = msg.header("From")
    set_callee msg.header("From")
    @last_Via = msg.headers["Via"]
    @last_CSeq = CSeq.new(msg.header("CSeq"))
    msg
  end

  def calculate_cseq type, method
    if (type == :response)
      @last_CSeq.to_s
    elsif (method == "ACK")
      "#{@last_CSeq.num} ACK"
    else
      @cseq_number = @cseq_number + 1
      "#{@cseq_number} #{method}"
    end
  end

  def build_message headers, body, type, method=nil, code=nil, phrase=nil
    defaults = {
      "From" => @last_From,
      "To" => @last_To,
      "Call-ID" => @cid,
      "CSeq" => calculate_cseq(type, method),
      "Via" => @last_Via,
      "Max-Forwards" => "70",
      "Content-Length" => "0",
      "User-Agent" => "Quaff SIP Scripting Engine",
      "Contact" => "<sip:quaff@#{Utils::local_ip}:#{@cxn.local_port};transport=#{@cxn.transport};ob>",
    }

    if @instance_id
      defaults["Contact"] += ";+sip.instance=\"<urn:uuid:"+@instance_id+">\""
    end

    is_request = code.nil?
    if is_request
      defaults['Route'] = @routeset
    else
      defaults['Record-Route'] = @routeset
    end

    defaults.merge! headers

    SipMessage.new(method, code, phrase, @sip_destination, body, defaults.merge!(headers)).to_s

  end

  def send_something(msg, retrans)
    @cxn.send_msg(msg, @src)
    if retrans and (@transport == "UDP") then
      @retrans = true
      Thread.new do
        timer = @t1
        sleep timer
        while @retrans do
          #puts "Retransmitting on call #{ @cid }"
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
