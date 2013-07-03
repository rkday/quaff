require './quaff'

c = UDPSIPConnection.new(5060)
cid = c.get_new_call_id
puts cid
call = Call.new(c, cid)

data = call.recv_request("INVITE")
puts data['source'].remote_ip
puts data['source'].remote_port
call.send_response("100 Trying")
call.send_response("180 Ringing")
call.send_response("200 OK", true)
call.recv_request("ACK")
call.recv_request("BYE")
call.send_response("200 OK", true)
call.end_call
