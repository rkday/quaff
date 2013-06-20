require "oversip"
require "oversip/sip/sip.rb"
require "oversip/sip/sip_parser.so"
require "oversip/sip/constants.rb"
require "oversip/sip/core.rb"
require "oversip/sip/message.rb"
require "oversip/sip/request.rb"
require "oversip/sip/response.rb"
require "oversip/sip/uri.rb"
require "oversip/sip/name_addr.rb"
require "oversip/sip/message_processor.rb"
require "oversip/sip/listeners.rb"
require "oversip/sip/launcher.rb"
require "oversip/sip/server_transaction.rb"
require "oversip/sip/client_transaction.rb"
require "oversip/sip/transport_manager.rb"
require "oversip/sip/timers.rb"
require "oversip/sip/tags.rb"
require "oversip/sip/rfc3263.rb"
require "oversip/sip/client.rb"
require "oversip/sip/proxy.rb"
require "oversip/sip/uac.rb"
require "oversip/sip/uac_request.rb"
require 'socket'

class Connection

    def initialize(lport)
        @cxn = UDPSocket.new
        @cxn.bind("0.0.0.0", lport)
        @p = OverSIP::SIP::MessageParser.new
        @messages = {}
        @call_ids = Queue.new
        @dead_calls = {}
        start
    end

    def start
        Thread.new do
            while 1 do
                data, ip = @cxn.recvfrom(65535)
                body = data.split("\r\n\r\n")[1]
                @p.reset
                nread = @p.execute(data,0)
                #print @p.finished?
                if msg = @p.parsed then
                    @p.post_parsing
                    cid = msg.header "Call-ID"
                    if cid and not @dead_calls.has_key? cid then
                        #puts message.method
                        unless @messages.has_key? cid then
                            @messages[cid] = Queue.new
                            @call_ids.enq cid
                        end
                        @messages[cid].enq({"message" => msg, "body" => body, "source" => ip})
                        #puts data
                        #puts msg.body
                    end
                end
            end
        end
    end

    def send(data, ip, port)
        @cxn.send(data, 0, ip, port)
    end

    def get_new_call_id
        @call_ids.deq
    end

    def get_new_message(cid)
        @messages[cid].deq
    end

    def state
        while not @call_ids.empty?
            cid = @call_ids.deq
            puts cid
            h = @messages[cid].deq
            puts h["message"].to_s
            puts "\n"
            puts h["message"].body
        end
    end

    def mark_call_dead(cid)
        del @messages[cid]
        now = Time.now
        @dead_calls[cid] = now + 30
        @dead_calls = @dead_calls.keep_if {|k, v| v > now}
    end
end

class SipConnection < Connection

end

class Call

    def initialize(cxn, cid)
        @cxn, @cid = cxn, cid
        @retrans = nil
        @t1, @t2 = 0.5, 32
    end

    def recv_request(method)
        data = @cxn.get_new_message @cid
        @retrans = nil
        unless data["message"].request? and data["message"].sip_method.to_s == method
            raise
        end
        @port, @ip = data["source"][1], data["source"][3]
        @last_To = data["message"].header("To")
        @last_From = data["message"].header("From")
        @last_Via = data["message"].header("Via")
        @last_CSeq = data["message"].header("CSeq")
        data
    end

    def send(code, retrans=nil)
        msg = "SIP/2.0 #{ code }\r
Via: #{ @last_Via }\r
From: #{ @last_From }\r
To: #{ @last_To };tag=6171SIPpTag001\r
Call-ID: #{ @cid }\r
CSeq: #{ @last_CSeq }\r
Contact: <sip:127.0.1.1:5060;transport=UDP>\r
Content-Length: 0\r
"
    @cxn.send(msg, @ip, @port)
    if retrans then
        @retrans = true
        Thread.new do
            timer = @t1
            sleep timer
            while @retrans do
                #puts "Retransmitting on call #{ @cid }"
                @cxn.send(msg, @ip, @port)
                timer *=2
                if timer < @t2 then
                    raise "Too many retransmits!"
                end
                sleep timer
            end
        end
    end

    def end_call
        @cxn.mark_call_dead @cid
    end

end

