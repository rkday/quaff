require 'socket'
require 'system/getifaddrs'

module Quaff

module Utils #:nodoc:
def Utils.local_ip
  addrs = System.get_ifaddrs
  if addrs.empty?
    "0.0.0.0"
  elsif (addrs.size == 1)
    addrs[0][:inet_addr]
  else
    addrs.select {|k, v| k != :lo}.shift[1][:inet_addr]
  end
end

def Utils.pid
    Process.pid
end

def Utils.new_call_id
    "#{pid}_#{Time.new.to_i}@#{local_ipv4}"
end

def Utils.new_branch
    "z9hG4bK#{Time.new.to_f}"
end

def Utils.paramhash_to_str params
  params.collect {|k, v| if (v == true) then ";#{k}" else ";#{k}=#{v}" end}.join("")
end

end
end
