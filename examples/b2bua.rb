require_relative '../quaff'

c = TCPSIPConnection.new(5067)

incoming_cid = c.get_new_call_id
incoming_call = Call.new(c, incoming_cid)

c.add_call_id("1")
outgoing_call = Call.new(c, "1")
outgoing_call.set_callee("test@example.com")
sock = TCPSocket.new 'localhost', 5060
outgoing_call.setdest(TCPSource.new(sock))
c.add_sock sock

incoming_call.recv_request("INVITE")
incoming_call.send_response("100 Trying")
outgoing_call.send_request("INVITE")

outgoing_call.recv_response("180")
outgoing_call.recv_response("200")
outgoing_call.send_request("ACK")

incoming_call.send_response("180 Ringing")
incoming_call.send_response("200 OK")
incoming_call.recv_request("ACK")

incoming_call.recv_request("BYE")
incoming_call.send_response("200 OK")
incoming_call.end_call

outgoing_call.send_request("BYE")
outgoing_call.recv_response("200")
puts "Successful call!"
outgoing_call.end_call








