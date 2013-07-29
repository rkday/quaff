require 'socket'
require 'thread'
require_relative './sip_parser2.rb'
require_relative './sources.rb'

class BaseConnection
    def initialize(lport)
        @lport = lport
        initialize_connection lport
        initialize_queues
        start
    end

    def local_port
        @lport
    end

    def initialize_queues
        @messages = {}
        @call_ids = Queue.new
        @dead_calls = {}
        @sockets
    end

    def start
        Thread.new do
            loop do
                recv_msg
            end
        end
    end

    def queue_msg(msg, source)
        cid = @parser.message_identifier msg
        if cid and not @dead_calls.has_key? cid then
            unless @messages.has_key? cid then
                add_call_id cid
                @call_ids.enq cid
            end
        @messages[cid].enq({"message" => msg, "source" => source})
        end
    end

    def add_call_id cid
        @messages[cid] = Queue.new
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
    attr_accessor :sockets

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
        @parser.parse_start
        msg = nil
        while msg.nil? do
            line = sock.gets
            msg = @parser.parse_partial line
        end
        queue_msg msg, TCPSource.new(sock)
    end

    def add_sock sock
      @sockets.push sock
    end

end

class UDPSIPConnection < BaseConnection

    def recv_msg
        data, addrinfo = @cxn.recvfrom(65535)
        #puts "DATA:"
        #puts data
        @parser.parse_start
        msg = @parser.parse_partial(data)
        #puts "PARSED MESSAGE:"
        #puts msg.headers
        queue_msg msg, UDPSource.new(addrinfo) unless msg.nil?
    end

    def initialize_connection(lport)
        @cxn = UDPSocket.new
        @cxn.bind('0.0.0.0', lport)
        @sockets = []
        @parser = SipParser.new
    end

end

