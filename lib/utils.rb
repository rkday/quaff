require 'socket'
require 'facter'

module Quaff

module Utils
def Utils.local_ip
  Facter.value("ipaddress")
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
end
end
