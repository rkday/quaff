# -*- coding: us-ascii -*-
require 'socket'
require 'thread'
require 'timeout'
require 'resolv'
require 'digest/md5'
#require 'milenage'
require_relative './sip_parser.rb'
require_relative './sources.rb'

module Quaff
  class BaseEndpoint
    attr_accessor :msg_trace, :uri, :sdp_port, :sdp_socket

    def setup_sdp
      @sdp_socket = UDPSocket.new
      @sdp_socket.bind('0.0.0.0', 0)
      @sdp_port = @sdp_socket.addr[1]
    end

    def generate_call_id
      digest = Digest::MD5.hexdigest(rand(60000).to_s)
    end

    def terminate
    end

    def add_sock sock
    end

    def incoming_call *args
      call_id ||= get_new_call_id
      puts "Call-Id for endpoint on #{@lport} is #{call_id}" if @msg_trace
      Call.new(self, call_id, *args)
    end

    def outgoing_call to_uri
      call_id = generate_call_id
      puts "Call-Id for endpoint on #{@lport} is #{call_id}" if @msg_trace
      Call.new(self, call_id, @uri, @outbound_connection, to_uri)
    end

    def create_client(uri, username, password, outbound_proxy, outbound_port=5060)
    end

    def create_server(uri, local_port=5060, outbound_proxy=nil, outbound_port=5060)

    end

    def create_aka_client(uri, username, key, op, outbound_proxy, outbound_port=5060)
    end

    def initialize(uri, username, password, local_port, outbound_proxy=nil, outbound_port=5060)
      @uri = uri
      @resolver = Resolv::DNS.new
      @username = username
      @password = password
      @lport = local_port
      initialize_connection
      if outbound_proxy
        @outbound_connection = new_connection(outbound_proxy, outbound_port)
      end
      initialize_queues
      start
    end

    def local_port
        @lport
    end

    def add_call_id cid
        @messages[cid] ||= Queue.new
    end

    def get_new_call_id time_limit=30
        Timeout::timeout(time_limit) { @call_ids.deq }
    end

    def get_new_message(cid, time_limit=30)
      Timeout::timeout(time_limit) { @messages[cid].deq }
    end

    def mark_call_dead(cid)
        @messages.delete cid
        now = Time.now
        @dead_calls[cid] = now + 30
        @dead_calls = @dead_calls.keep_if {|k, v| v > now}
    end

    def send_msg(data, source)
        puts "Endpoint on #{@lport} sending #{data} to #{source.inspect}" if @msg_trace
        source.send_msg(@cxn, data)
    end

    def set_aka_credentials key, op
      @kernel = Milenage.Kernel key
      @kernel.op = op
    end

    def register expires="3600", aka=false
      @reg_call ||= outgoing_call(@uri)
      auth_hdr = Quaff::Auth.gen_empty_auth_header @username
      @reg_call.update_branch
      @reg_call.send_request("REGISTER", "", {"Authorization" =>  auth_hdr, "Expires" => expires.to_s})
      response_data = @reg_call.recv_response("401|200")
      if response_data.status_code == "401"
        if aka
          rand = Quaff::Auth.extract_rand response_data.header("WWW-Authenticate")
          password = @kernel.f3 rand
        else
          password = @password
        end
        auth_hdr = Quaff::Auth.gen_auth_header response_data.header("WWW-Authenticate"), @username, @password, "REGISTER", @uri
        @reg_call.update_branch
        @reg_call.send_request("REGISTER", "", {"Authorization" =>  auth_hdr, "Expires" => expires.to_s})
        response_data = @reg_call.recv_response("200")
      end
      return response_data # always the 200 OK
    end

    def unregister
      register 0
    end

    private
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
      puts "Endpoint on #{@lport} received #{msg} from
                          ##{source.inspect}" if @msg_trace
      msg.source = source
      cid = @parser.message_identifier msg
      if cid and not @dead_calls.has_key? cid then
        unless @messages.has_key? cid then
          add_call_id cid
          @call_ids.enq cid
        end
        @messages[cid].enq(msg)
      end
    end
  end

  class TCPSIPEndpoint < BaseEndpoint
    attr_accessor :sockets

    def initialize_connection
      if @lport != :anyport
        @cxn = TCPServer.new(@lport)
      else
        @cxn = TCPServer.new(0)
        @lport = @cxn.addr[1]
      end
      @parser = SipParser.new
      @sockets = []
    end

    def transport
      "TCP"
    end

    def new_source host, port
      return TCPSource.new host, port
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


    alias_method :new_connection, :new_source
    private
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
  end

  class UDPSIPEndpoint < BaseEndpoint

    def transport
      "UDP"
    end

    def new_source host, port
      if /^(\d+\.){3}\d+$/ =~ host
        return UDPSource.new host, port
      else
        return UDPSource.new @resolver.getaddress(host).to_s, port
      end
    end

    alias_method :new_connection, :new_source

    private
    def initialize_connection
      @cxn = UDPSocket.new
      if @lport != :anyport
        @cxn.bind('0.0.0.0', @lport)
      else
        @cxn.bind('0.0.0.0', 0)
        @lport = @cxn.addr[1]
      end
      @sockets = []
      @parser = SipParser.new
    end

    def recv_msg
        data, addrinfo = @cxn.recvfrom(65535)
        @parser.parse_start
        msg = @parser.parse_partial(data)
        queue_msg msg, UDPSourceFromAddrinfo.new(addrinfo) unless msg.nil?
    end
  end

end
