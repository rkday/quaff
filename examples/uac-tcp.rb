require_relative '../quaff'

c = TCPSIPConnection.new(5061)
c.add_call_id("1")
call = Call.new(c, "1")
call.set_callee("test@example.com")
#call.setdest(UDPSource.new(["", 5060, "", "localhost"]))
sock = TCPSocket.new 'localhost', 5060
call.setdest(TCPSource.new(sock))
c.add_sock sock

call.send_request("INVITE")
call.recv_response("180")
call.recv_response("200")
call.send_request("ACK")
sleep 2
call.send_request("BYE")
call.recv_response("200")
puts "Successful call!"
call.end_call
