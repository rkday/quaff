require 'socket'
module Quaff
  class Source
    def remote_ip
      @ip
    end

    def remote_port
      @port
    end

    def close cxn
    end

    def sock
      nil
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
    attr_reader :sock

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
