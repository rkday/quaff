require 'socket'

def local_ipv4
    Socket.ip_address_list.select {|i| !(i.ipv6? || i.ipv4_loopback?)}[0].ip_address
end

def local_ipv6
    Socket.ip_address_list.select {|i| !(i.ipv4? || i.ipv6_loopback?)}[0].ip_address
end

def pid
    Process.pid
end

def new_call_id
    "#{pid}_#{Time.new.to_i}@#{local_ipv4}"
end

def new_branch
    "z9hG4bK#{Time.new.to_f}"
end

