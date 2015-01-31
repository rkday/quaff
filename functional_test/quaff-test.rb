require 'test_helper'
require 'quaff'

passed = false

body = "abcd"

e = Quaff::TCPSIPEndpoint.new("sip:test@example.com", "", "", 5060)
e2 = Quaff::TCPSIPEndpoint.new("sip:test@example.com", "", "", 6000, "127.0.0.1")

c = e2.outgoing_call("sip:anyone@example.com")
c.send_request("REGISTER", body: body)
c.send_request("REGISTER", body: body)

c2 = e.incoming_call


c2.recv_request("REGISTER")
c2.recv_request("REGISTER")

e3 = Quaff::UDPSIPEndpoint.new("sip:test@example.com", "", "", 5060)
e4 = Quaff::UDPSIPEndpoint.new("sip:test@example.com", "", "", 6000, "127.0.0.1")

c = e4.outgoing_call("sip:anyone@example.com")
c.send_request("REGISTER", body: body)
c.send_request("REGISTER", body: body)

c2 = e3.incoming_call


c2.recv_request("REGISTER")
c2.recv_request("REGISTER")

passed = true

puts passed
