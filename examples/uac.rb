require_relative '../quaff'

c = UDPSIPConnection.new(5061)
c.add_call_id("1")
call = Call.new(c, "1")
call.set_callee("test@example.com")
call.setdest(UDPSource.new(["", 5060, "", "localhost"]))

call.send_request("INVITE")
sleep 15
call.recv_response("180")
call.recv_response("200")
call.send_request("ACK")
sleep 2
call.send_request("BYE")
call.recv_response("200")
puts "Successful call!"
call.end_call
