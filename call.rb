# -*- coding: us-ascii -*-
require_relative './utils.rb'
require_relative './sources.rb'

class CSeq
  def initialize cseq_str
    @num, @method = cseq_str.split
    @num = @num.to_i
  end

  def increment
    @num = @num +1
    to_s
  end

  def to_s
    "#{@num.to_s} #{@method}"
  end
  
end

class Call

  def initialize(cxn, cid, uri="sip:5557777888@#{QuaffUtils.local_ip}")
    @cxn, @cid = cxn, cid
    @cxn.add_call_id @cid
    @uri = uri
    @retrans = nil
    @t1, @t2 = 0.5, 32
    @last_From = "<#{uri}>"
    update_branch
  end

  def update_branch
    @last_Via = "SIP/2.0/#{@cxn.transport} #{QuaffUtils.local_ip}:#{@cxn.local_port};rport;branch=#{QuaffUtils.new_branch}"
  end
  
  def recv_something
    data = @cxn.get_new_message @cid
    @retrans = nil
    @src = data['source']
    @last_To = data["message"].header("To")
    @last_From = data["message"].header("From")
    @sip_destination ||= data["message"].header("From")
    @last_Via = data["message"].headers["Via"]
    @last_RR = data["message"].headers["Record-Route"]
    @last_CSeq = CSeq.new(data["message"].header("CSeq"))
    data
  end

  def set_callee uri
    @sip_destination = "#{uri}"
    @last_To = "<#{uri}>"
  end

  def setdest source, options={}
    @src = source
    if options[:recv_from_this]
      @cxn.add_sock source.sock
    end
  end

  def recv_request(method)
    data = recv_something
    unless data["message"].type == :request and Regexp.new(method) =~ data["message"].method
      raise data['message']
    end
    #puts "Expected #{method}, got #{data["message"].method}"
    data
  end

  def recv_response(code)
    data = recv_something
    unless data["message"].type == :response and Regexp.new(code) =~ data["message"].status_code
      raise "Expected #{ code}, got #{data["message"].status_code}"
    end
    #puts "Expected #{ code}, got #{data["message"].status_code}"
    data
  end

  def send_response(code, retrans=nil, headers={})
    msg = build_message headers, :response, code
    send_something(msg, retrans)
  end

  def send_request(method, sdp=true, retrans=nil, headers={})
    sdp="v=0
      o=user1 53655765 2353687637 IN IP4 #{QuaffUtils.local_ip}
      s=-
      c=IN IP4 #{QuaffUtils.local_ip}
      t=0 0
      m=audio 7000 RTP/AVP 0
      a=rtpmap:0 PCMU/8000"

    msg = build_message headers, :request, method
    send_something(msg, retrans)
  end

  def build_message headers, type, method_or_code
    defaults = {
      "From" => @last_From,
      "To" => @last_To,
      "Call-ID" => @cid,
      "CSeq" => (/\d+/ =~ method_or_code) ? @last_CSeq.to_s : (method_or_code == "ACK") ? @last_CSeq.increment : "1 #{method_or_code}",
      "Via" => @last_Via,
      #"Record-Route" => @last_RR,
      "Max-Forwards" => "70",
      "Content-Length" => "0",
      "User-Agent" => "Quaff SIP Scripting Engine",
      "Contact" => "<sip:quaff@#{QuaffUtils.local_ip}:#{@cxn.local_port};transport=#{@cxn.transport};ob>",
    }


    defaults.merge! headers


    if type == :request
      msg = "#{method_or_code} #{@sip_destination} SIP/2.0\r\n"
    else
      msg = "SIP/2.0 #{ method_or_code }\r\n"
    end

    defaults.each do |key, value|
      if value.nil?
      elsif not value.kind_of? Array
        msg += "#{key}: #{value}\r\n"
      else value.each do |subvalue|
          msg += "#{key}: #{subvalue}\r\n"
        end
      end
    end
    msg += "\r\n"

    msg
  end

  def send_something(msg, retrans)
    @cxn.send(msg, @src)
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

  def end_call
    @cxn.mark_call_dead @cid
    @src.close @cxn
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

  def register username=@username, password=@password, expires="3600"
    @username, @password = username, password
    send_request("REGISTER", nil, nil, { "Expires" => expires.to_s })
    response_data = recv_response("401|200")
    if response_data['message'].status_code == "401"
      send_request("ACK")
      auth_hdr = gen_auth_header response_data['message'].header("WWW-Authenticate"), username, password, "REGISTER", @uri
      update_branch
      send_request("REGISTER", nil, nil, {"Authorization" =>  auth_hdr, "Expires" => expires.to_s})
      recv_response("200")
    end
    return true
  end

  def unregister
    register @username, @password, 0
  end

end
