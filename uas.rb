require './quaff'

c = Connection.new(5060)
cid = c.get_new_call_id
call = Call.new(c, cid)

call.recv_request("INVITE")
call.send("100 Trying")
call.send("180 Ringing")
call.send("200 OK")
call.recv_request("ACK")
call.recv_request("BYE")
call.send("200 OK")
