require './quaff'

c = Connection.new(5060)
cid = c.get_new_call_id
call = Call.new(c, cid)

data = call.recv_request("INVITE")
if data["message"].header("Contact").nil? then
    raise "INVITE was missing a Contact header!"
end
call.send("100 Trying")
call.send("180 Ringing")
call.send("200 OK")
data = call.recv_request("ACK")
if data["message"].header("X-Anticipated-Header").nil? then
    raise "ACK was missing an expected header!"
end
call.recv_request("BYE")
call.send("200 OK")
