class Call

    def initialize(cxn, cid)
        @cxn, @cid = cxn, cid
        @retrans = nil
        @t1, @t2 = 0.5, 32
    end

    def recv_something
        data = @cxn.get_new_message @cid
        @retrans = nil
        @src = data['source']
        @last_To = data["message"].header("To")
        @last_From = data["message"].header("From")
        @last_Via = data["message"].header("Via")
        @last_CSeq = data["message"].header("CSeq")
        data
    end

    def recv_request(method)
        data = recv_something
        unless data["message"].request? and data["message"].sip_method.to_s == method
            raise
        end
        data
    end

    def recv_response(code)
        data = recv_something
        unless data["message"].response? and data["message"].status_code == code
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

    def send_request(method, sdp=True, retrans=nil)

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
      o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
      s=-
      c=IN IP[media_ip_type] [media_ip]
      t=0 0
      m=audio [media_port] RTP/AVP 0
      a=rtpmap:0 PCMU/8000"

      defaults = {
          "From" => @last_From,
          "To" => @last_To,
          "Call-ID" => @cid,
          "Via" => @last_Via,
          "Max-Forwards" => "70",
          "Contact" => "<sip:quaff#{local_ip}:#{local_port}>",
      }

      msg = req_uri
      for key in defaults do
          if not key.kind_of? Array
              msg += "#{key}: #{defaults[key]}\r\n"
          else defaults[key].each do |value|
              msg += "#{key}: #{value}\r\n"
          end
          end
      end

      msg = "INVITE sip:[service]@[remote_ip]:[remote_port] SIP/2.0
      Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
      From: sipp <sip:sipp@[local_ip]:[local_port]>;tag=[pid]Quaff[call_number]
      To: sut <sip:[service]@[remote_ip]:[remote_port]>
      Call-ID: [call_id]
      CSeq: 1 INVITE
      Contact: sip:sipp@[local_ip]:[local_port]
      Max-Forwards: 70
      Subject: Quaff SIP Test
      Content-Type: application/sdp
      Content-Length: [len]

      "
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
    end

end
