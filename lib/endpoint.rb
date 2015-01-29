# -*- coding: us-ascii -*-
require 'socket'
require 'thread'
require 'timeout'
require 'resolv'
require 'securerandom'
require_relative './sip_parser.rb'
require_relative './sources.rb'
require 'digest/md5'
require 'stringio'

module Quaff
  class BaseEndpoint
    attr_accessor :msg_trace, :uri, :sdp_port, :sdp_socket, :local_hostname
    attr_reader :msg_log, :local_port, :instance_id

    # Creates an SDP socket bound to an ephemeral port
    def setup_sdp
      @sdp_socket = UDPSocket.new
      @sdp_socket.bind('0.0.0.0', 0)
      @sdp_port = @sdp_socket.addr[1]
    end

    def terminate
      @terminated = true
      terminate_specific
    end

    # Cleans up the endpoint - designed to be overriden by
    # per-transport subclasses
    def terminate_specific
    end

    # Adds a socket connection to another UA - designed to be
    # overriden by per-transport subclasses
    def add_sock sock
    end

    def add_contact_param name, value
      @contact_params[name] = value
    end

    def add_contact_uri_param name, value
      @contact_uri_params[name] = value
    end

    def remove_contact_param name
      @contact_params.delete name
    end

    def remove_contact_uri_param name
      @contact_uri_params.delete name
    end
    
    def instance_id= id
      add_contact_param "+sip.instance", "\"<urn:uuid:#{id}>\""
    end
    
    # Retrieves the next unhandled call for this endpoint and returns
    # a +Call+ object representing it
    def incoming_call
      begin
        call_id = get_new_call_id
      rescue Timeout::Error
        raise "#{ @uri } timed out waiting for new incoming call"
      end

      puts "Call-Id for endpoint on #{@local_port} is #{call_id}" if @msg_trace
      Call.new(self, call_id, @instance_id, @uri)
    end

    # Creates a +Call+ object representing a new outbound call
    def outgoing_call to_uri
      call_id = generate_call_id
      puts "Call-Id for endpoint on #{@local_port} is #{call_id}" if @msg_trace
      Call.new(self, call_id, @instance_id, @uri, @outbound_connection, to_uri)
    end

    # Not yet ready for use
    def create_client(uri, username, password, outbound_proxy, outbound_port=5060) # :nodoc:
    end

    # Not yet ready for use
    def create_server(uri, local_port=5060, outbound_proxy=nil, outbound_port=5060) # :nodoc:
    end

    # Not yet ready for use
    def create_aka_client(uri, username, key, op, outbound_proxy, outbound_port=5060) # :nodoc:
    end

    # Constructs a new endpoint
    # Params:
    # +uri+:: The SIP URI of this endpoint
    # +username+:: The authentication username of this endpoint
    # +password+:: The authentication password of this endpoint
    # +local_port+:: The port this endpoint should bind to. Use
    # ':anyport' to bind to an ephemeral port.
    # +outbound_proxy+:: The outbound proxy where all requests should
    # be directed. Optional, but it only makes sense to omit it when
    # Quaff is emulating a server rather than a client.
    # +outbound_port+:: The port of the outbound proxy
    def initialize(uri, username, password, local_port, outbound_proxy=nil, outbound_port=5060)
      @msg_log = Array.new
      @uri = uri
      @resolver = Resolv::DNS.new
      @username = username
      @password = password
      @local_host = Utils::local_ip
      @local_port = local_port
      initialize_connection
      if outbound_proxy
        @outbound_connection = new_connection(outbound_proxy, outbound_port)
      end
      @hashes = []
      @contact_params = {}
      @contact_uri_params = {"transport" => transport, "ob" => true}
      @terminated = false
      @local_hostname = Utils::local_ip
      initialize_queues
      start
    end

    def contact_header
      param_str = Utils.paramhash_to_str(@contact_params)
      uri_param_str = Utils.paramhash_to_str(@contact_uri_params)
      "<sip:quaff@#{@local_hostname}:#{@local_port}#{uri_param_str}>#{param_str}"
    end

    def send_msg(data, source) # :nodoc:
      @msg_log.push "Endpoint on #{@local_port} sending:\n\n#{data.strip}\n\nto #{source.inspect}"
      puts "Endpoint on #{@local_port} sending #{data} to #{source.inspect}" if @msg_trace
        source.send_msg(@cxn, data)
    end

    # Not yet ready for use
    def set_aka_credentials key, op # :nodoc:
      @kernel = Milenage.Kernel key
      @kernel.op = op
    end

    # Utility method - handles a REGISTER/200 or
    # REGISTER/401/REGISTER/200 flow to authenticate the subscriber.
    # Currently only supports SIP Digest authentication. Re-REGISTERs
    # are not handled; if you need long-running endpoints you should
    # create a thread to re-REGISTER them yourself.
    #
    # Returns the +Message+ representing the 200 OK, or throws an
    # exception on failure to authenticate successfully.
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

    # Only designed for use by the Call class. Retrieves a new message
    # on a particular call. If no new message has been received,
    # blocks for up to time_limit seconds waiting for one. If nothing
    # arrives, raises a TimeoutError.
    def get_new_message(cid, time_limit=30) # :nodoc:
      Timeout::timeout(time_limit) { @messages[cid].deq }
    end



    # Flags that a particular call has ended, and any more messages
    # using it shold be ignored.
    def mark_call_dead(cid)
        @messages.delete cid
        now = Time.now
        @dead_calls[cid] = now + 30
        @dead_calls = @dead_calls.keep_if {|k, v| v > now}
    end
    private

    # Creates a random Call-ID
    def generate_call_id
      call_id = SecureRandom::hex
      add_call_id call_id
      return call_id
    end

    def get_new_call_id time_limit=30
        Timeout::timeout(time_limit) { @call_ids.deq }
    end

    def no_new_calls?
      return @call_ids.empty?
    end

    # Sets up the internal structures needed to handle calls for a new Call-ID.
    def add_call_id cid
        @messages[cid] ||= Queue.new
    end

    def initialize_queues
        @messages = {}
        @call_ids = Queue.new
        @dead_calls = {}
        @sockets
    end

    def start
        Thread.new do
            until @terminated do
                recv_msg
            end
        end
    end

    def is_retransmission? msg
      @hashes.include? Digest::MD5.hexdigest(msg.to_s)
    end

    def queue_msg(msg, source)
      if is_retransmission? msg
        @msg_log.push "Endpoint on #{@local_port} received retransmission"
        puts "Endpoint on #{@local_port} received retransmission" if @msg_trace
        return
      end

      @hashes.push Digest::MD5.hexdigest(msg.to_s)

      @msg_log.push "Endpoint on #{@local_port} received:\n\n#{msg.to_s.strip}\n\nfrom #{source.inspect}"
      puts "Endpoint on #{@local_port} received #{msg} from #{source.inspect}" if @msg_trace
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

    def transport
      "TCP"
    end

    def new_source host, port
      return TCPSource.new host, port
    end

    def add_sock sock
      @sockets.push sock
    end

    def terminate_specific
      oldsockets = @sockets.dup
      @sockets = []
      oldsockets.each do |s| s.close unless s.closed? end
      mycxn = @cxn
      @cxn = nil
      mycxn.close
    end


    alias_method :new_connection, :new_source

    private

    def initialize_connection
      if @local_port != :anyport
        @cxn = TCPServer.new(@local_port)
      else
        @cxn = TCPServer.new(0)
        @local_port = @cxn.addr[1]
      end
      @parser = SipParser.new
      @sockets = []
    end


    def recv_msg
        warn "recv_msg called for an endpoint with no sockets - will tight-loop" if (@sockets.empty? and @cxn.nil?)
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
      msg = @parser.parse_from_io(sock)
      
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
      if @local_port != :anyport
        @cxn.bind('0.0.0.0', @local_port)
      else
        @cxn.bind('0.0.0.0', 0)
        @local_port = @cxn.addr[1]
      end
      @sockets = []
      @parser = SipParser.new
    end

    def recv_msg
      data, addrinfo = @cxn.recvfrom(65535)
      @parser.parse_start
      msg = @parser.parse_from_io(StringIO.new(data))
      queue_msg msg, UDPSourceFromAddrinfo.new(addrinfo) unless msg.nil?
    end
  end

end
