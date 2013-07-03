require 'socket'
require './sip_parser.rb'
require './sources.rb'

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

    def send(data, source)
        source.send(@cxn, data)
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
        queue_msg msg, TCPSource.new(sock)
    end

end

class UDPSIPConnection < BaseConnection

    def recv_msg
        data, addrinfo = @cxn.recvfrom(65535)
        msg = @parser.parse_start(data)
        queue_msg msg, UDPSource.new(addrinfo)
    end

    def initialize_connection(lport)
        @cxn = UDPSocket.new
        @cxn.bind('0.0.0.0', lport)
        @sockets = []
        @parser = SipParser.new
    end

end


