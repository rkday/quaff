require 'socket'

class Source
    def remote_ip
        @ip
    end

    def remote_port
        @port
    end

    def close cxn
    end
end

class UDPSource < Source
    def initialize addrinfo
        @addrinfo = addrinfo
        @ip, @port = @addrinfo[3], @addrinfo[1]
    end

    def send cxn, data
        cxn.send(data, 0, @ip, @port)
    end
end


class TCPSource < Source
	attr_reader :sock

    def initialize sock
        @sock = sock
        @port, @ip = Socket.unpack_sockaddr_in(@sock.getpeername)
    end

    def send _, data
        @sock.puts data
    end

    def close cxn
        @sock.close
        cxn.sockets.delete(@sock)
    end
end


