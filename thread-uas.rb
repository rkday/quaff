require './quaff'

c = SipConnection.new(5060)
loop do
cid = c.get_new_call_id
Thread.new do
call = Call.new(c, cid)

call.recv_request("INVITE")
call.send("100 Trying")
call.send("180 Ringing")
sleep 15
call.send("200 OK", true)
call.recv_request("ACK")
call.recv_request("BYE")
call.send("200 OK")
call.end_call
end
end
