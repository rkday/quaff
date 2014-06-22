require 'socket'
module Quaff
  # A Source is an abstraction representing an IP
  # address/port/transport where a SIP message originates from or can
  # be sent to. It allows users to abstract over TCP and UDP sockets.
  class Source
    attr_reader :ip, :port, :transport, :sock

    # Designed to be overriden by subclasses
    def close cxn
    end

    def to_s
      "#{@ip}:#{@port} (#{@transport})"
    end
  end

  class UDPSource < Source
    def initialize ip, port
      @transport = "UDP"
      @ip, @port = ip, port
    end

    def send_msg cxn, data
      cxn.send(data, 0, @ip, @port)
    end
  end

  class UDPSourceFromAddrinfo < UDPSource
    def initialize addrinfo
      @transport = "UDP"
      @ip, @port = addrinfo[3], addrinfo[1]
    end
  end


  class TCPSource < Source

    def initialize ip, port
      @transport = "TCP"
      @sock = TCPSocket.new ip, port
      @port, @ip = port, ip
    end

    def send_msg _, data
      @sock.sendmsg data
    end

    def close cxn
      @sock.close
      cxn.sockets.delete(@sock)
    end
  end

  class TCPSourceFromSocket < TCPSource
    def initialize sock
      @transport = "TCP"
      @sock = sock
      @port, @ip = Socket.unpack_sockaddr_in(@sock.getpeername)
    end
  end
end
