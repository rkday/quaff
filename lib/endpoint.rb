# -*- coding: us-ascii -*-
require 'socket'
require 'thread'
require 'timeout'
require_relative './sip_parser.rb'
require_relative './sources.rb'

class BaseEndpoint
    attr_accessor :msg_trace

    def terminate
    end

    def add_sock sock
    end

    def new_call call_id=nil, *args
      call_id ||= get_new_call_id
      puts "Call-Id for endpoint on #{@lport} is #{call_id}" if @msg_trace
      Call.new(self, call_id, *args)
    end

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
        puts "Endpoint on #{@lport} received #{msg} from #{source.inspect}" if @msg_trace
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
        @messages[cid] ||= Queue.new
    end

    def get_new_call_id time_limit=5
        Timeout::timeout(time_limit) { @call_ids.deq }
    end

    def get_new_message(cid, time_limit=5)
        Timeout::timeout(time_limit) { @messages[cid].deq }
    end

    def mark_call_dead(cid)
        @messages.delete cid
        now = Time.now
        @dead_calls[cid] = now + 30
        @dead_calls = @dead_calls.keep_if {|k, v| v > now}
    end

    def send(data, source)
        puts "Endpoint on #{@lport} sending #{data} to #{source.inspect}" if @msg_trace
        source.send(@cxn, data)
    end

end

class TCPSIPEndpoint < BaseEndpoint
    attr_accessor :sockets

    def initialize_connection(lport)
        @cxn = TCPServer.new(lport)
        @parser = SipParser.new
        @sockets = []
    end

    def transport
      "TCP"
    end

    def new_source ip, port
      return TCPSource.new ip, port
    end

    alias_method :new_connection, :new_source

    def recv_msg
        select_response = IO.select(@sockets, [], [], 0) || [[]]
        readable = select_response[0]
        for sock in readable do
            recv_msg_from_sock sock
        end
        begin
            if @cxn
              sock = @cxn.accept_nonblock
              @sockets.push sock if sock
            end
        rescue IO::WaitReadable, Errno::EINTR
            sleep 0.3
        end
    end

    def recv_msg_from_sock(sock)
        @parser.parse_start
        msg = nil
        while msg.nil? and not sock.closed? do
            line = sock.gets
            msg = @parser.parse_partial line
        end
        queue_msg msg, TCPSourceFromSocket.new(sock)
    end

    def add_sock sock
      @sockets.push sock
    end

    def terminate
      oldsockets = @sockets.dup
      @sockets = []
      oldsockets.each do |s| s.close unless s.closed? end
      mycxn = @cxn
      @cxn = nil
      mycxn.close
    end

end

class UDPSIPEndpoint < BaseEndpoint

    def recv_msg
        data, addrinfo = @cxn.recvfrom(65535)
        @parser.parse_start
        msg = @parser.parse_partial(data)
        queue_msg msg, UDPSourceFromAddrinfo.new(addrinfo) unless msg.nil?
    end

    def transport
      "UDP"
    end
    
    def new_source ip, port
      return UDPSource.new ip, port
    end
    
    alias_method :new_connection, :new_source
    
    def initialize_connection(lport)
        @cxn = UDPSocket.new
        @cxn.bind('0.0.0.0', lport)
        @sockets = []
        @parser = SipParser.new
    end

end

