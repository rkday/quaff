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

class BaseConnection
    def initialize(lport)
        initialize_connection lport
        initialize_queues
        start
    end

    def initialize_queues
        @messages = {}
        @call_ids = Queue.new
        @dead_calls = {}
        @sockets
    end

    def start
        Thread.new do
            while 1 do
                recv_msg
            end
        end
    end

    def queue_msg(msg, source)
        cid = @parser.message_identifier msg
        if cid and not @dead_calls.has_key? cid then
            unless @messages.has_key? cid then
                @messages[cid] = Queue.new
                @call_ids.enq cid
            end
            @messages[cid].enq({"message" => msg, "source" => source})
        end
    end

    def get_new_call_id
        @call_ids.deq
    end

    def get_new_message(cid)
        @messages[cid].deq
    end

    def mark_call_dead(cid)
        @messages.delete cid
        now = Time.now
        @dead_calls[cid] = now + 30
        @dead_calls = @dead_calls.keep_if {|k, v| v > now}
    end
end

class TCPSIPConnection < BaseConnection
    def initialize_connection(lport)
        @cxn = TCPServer.new(lport)
        @parser = SipParser.new
        @sockets = []
    end

    def recv_msg
        # This is subpar - should be event-driven
        for sock in @sockets do
            recv_msg_from_sock sock
        end
        begin
            sock = @cxn.accept_nonblock
            @sockets.push sock
        rescue IO::WaitReadable, Errno::EINTR
            sleep 0.3
        end
    end

    def recv_msg_from_sock(sock)
        msg = @parser.parse_start sock.gets
        while msg.nil? do
            msg = @parser.parse_partial sock.gets
        end
        queue_msg msg, sock
    end
    
    def send(data, source)
        source.puts(data)
    end

end

class UDPSIPConnection < BaseConnection

    def recv_msg
        data, addrinfo = @cxn.recvfrom(65535)
        ip, port = addrinfo[3], addrinfo[1]
        source = [ip, port]
        msg = @parser.parse_start(data)
        queue_msg msg, source
    end

    def initialize_connection(lport)
        @cxn = UDPSocket.new
        @cxn.bind('0.0.0.0', lport)
        @sockets = []
        @parser = SipParser.new
    end

    def send(data, source)
        ip, port = source
        @cxn.send(data, 0, ip, port)
    end

end

class SipParser
    def parse_start(data)
        @p = OverSIP::SIP::MessageParser.new
        @nread = 0
        @buf = ""
        @msg = nil
        parse_partial data
    end

    def parse_partial(data)
        @buf << data
        if not @p.finished? then
            @nread = @p.execute(@buf,@nread)
            if @p.finished?
                if @p.parsed.header("Content-Length").to_i == 0 then
                    return @p.parsed
                elsif data.index("\r\n\r\n") then
                    msg = @p.parsed
                    msg.body = data.split("\r\n\r\n")[1]
                    return msg
                else
                    return nil
                end
            else
                return nil
            end
        else
            @p.post_parsing
            @msg ||= @p.parsed
            body_len = @msg.header("Content-Length").to_i

            if @msg.body.nil?
                @msg.body = ""
            end

            if data.index("\r\n\r\n") then
                @msg.body = data.split("\r\n\r\n")[1]
            else
                @msg.body << data
            end

            if @msg.body.to_s.length >= body_len
                return @msg
            else
                return nil
            end
        end
    end

    def message_identifier(msg)
        msg.header "Call-ID"
    end

end

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

# local IP
# local port
# local media IP
# local media port
# IPv4 vs. IPv6
# UDP vs. TCP
# remote IP
# remote port
# process ID
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
