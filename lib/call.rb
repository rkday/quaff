# -*- coding: us-ascii -*-
require_relative './utils.rb'
require_relative './sources.rb'
require_relative './auth.rb'
require_relative './message.rb'

module Quaff
class CSeq # :nodoc:
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
  end

  def change_cid cid
    @cid = cid
    @cxn.add_call_id @cid
  end

  def update_branch
    @last_Via = "SIP/2.0/#{@cxn.transport} #{Quaff::Utils.local_ip}:#{@cxn.local_port};rport;branch=#{Quaff::Utils::new_branch}"
  end

  def create_dialog msg
    set_callee msg.first_header("Contact")
  end

  def set_callee uri
    if /<(.*)>/ =~ uri
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

  def recv_request(method)
    begin
      data = recv_something
    rescue
      raise "#{ @uri } timed out waiting for #{ method }"
    end
    unless data["message"].type == :request \
      and Regexp.new(method) =~ data["message"].method
      raise((data['message'].to_s || "Message is nil!"))
    end
    unless data['message'].all_headers("Record-Route").nil?
      @routeset = data['message'].all_headers("Record-Route")
    end
    data
  end

  def recv_response(code)
    begin
      data = recv_something
    rescue
      raise "#{ @uri } timed out waiting for #{ code }"
    end
    unless data["message"].type == :response \
      and Regexp.new(code) =~ data["message"].status_code
      raise "Expected #{ code}, got #{data["message"].status_code || data['message']}"
    end
    unless data['message'].all_headers("Record-Route").nil?
      @routeset = data['message'].all_headers("Record-Route").reverse
    end
    data
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
    data = @cxn.get_new_message @cid
    @retrans = nil
    @src = data['source']
    @last_To = data["message"].header("To")
    @last_From = data["message"].header("From")
    set_callee data["message"].header("From")
    @last_Via = data["message"].headers["Via"]
    @last_CSeq = CSeq.new(data["message"].header("CSeq"))
    data
  end

  def calculate_cseq type, method
    if (type == :response)
      @last_CSeq.to_s
    elsif (method == "ACK")
      @last_CSeq.to_s
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
