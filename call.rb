require_relative './utils.rb'

class Call

    def initialize(cxn, cid, dn="5557777888")
        @cxn, @cid = cxn, cid
        @retrans = nil
        @t1, @t2 = 0.5, 32
        @last_Via = "SIP/2.0/UDP 127.0.0.1:5060;branch=#{QuaffUtils.new_branch}"
        @last_From = "quaff <sip:#{dn}@127.0.0.1>"
    end

    def recv_something
        data = @cxn.get_new_message @cid
        @retrans = nil
        @src = data['source']
        @last_To = data["message"].header("To")
        @last_From = data["message"].header("From")
        @sip_destination ||= data["message"].header("From")
        @last_Via = data["message"].header("Via")
        @last_CSeq = data["message"].header("CSeq")
        data
    end

    def set_callee uri
        @sip_destination = uri
        @last_To = "<sip:#{uri}>"
    end

    def setdest source, options={}
        @src = source
	if options['recv_from_this']
		@cxn.add_sock source.sock
	end
    end

    def recv_request(method)
        data = recv_something
        unless data["message"].type == :request and data["message"].method == method
            raise
        end
        data
    end

    def recv_response(code)
        data = recv_something
        unless data["message"].type == :response and data["message"].status_code == code
            raise
        end
        data
    end

    def send_response(code, retrans=nil)
        msg = "SIP/2.0 #{ code }\r
Via: #{ @last_Via }\r
From: #{ @last_From }\r
To: #{ @last_To };tag=6171SIPpTag001\r
Call-ID: #{ @cid }\r
CSeq: #{ @last_CSeq }\r
Contact: <sip:127.0.1.1:5060;transport=UDP>\r
Content-Length: 0\r
\r
"
        send_something(msg, retrans)
    end

    def send_request(method, sdp=true, retrans=nil, headers={})

        # local port
        # local media port
        # UDP vs. TCP
        # remote IP
        # remote port
        # tag
        # SDP length
        # CSeq
        # Call-ID

        sdp="v=0
      o=user1 53655765 2353687637 IN IP4 #{QuaffUtils.local_ip}
      s=-
      c=IN IP4 #{QuaffUtils.local_ip}
      t=0 0
      m=audio 7000 RTP/AVP 0
      a=rtpmap:0 PCMU/8000"

      defaults = {
          "From" => @last_From,
          "To" => @last_To,
          "Call-ID" => @cid,
          #"CSeq" => (method == "ACK") ? @last_CSeq.increment : "1 #{method}",
          "CSeq" => "1 #{method}",
          "Via" => @last_Via,
          "Max-Forwards" => "70",
          "Contact" => "<sip:quaff@#{QuaffUtils.local_ip}:#{@cxn.local_port}>",
      }

      defaults.merge headers

      msg = "#{method} #{@sip_destination} SIP/2.0\r\n"
      defaults.each do |key, value|
          if not value.kind_of? Array
              msg += "#{key}: #{value}\r\n"
          else value.each do |subvalue|
              msg += "#{key}: #{subvalue}\r\n"
          end
          end
      end
      msg += "\r\n"

      send_something(msg, retrans)

    end

    def send_something(msg, retrans)
        @cxn.send(msg, @src)
        if retrans then
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

end
