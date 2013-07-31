require_relative '../../quaff/quaff.rb'
c = TCPSIPConnection.new(5070)

	incoming_cid = c.get_new_call_id
incoming_call = Call.new(c, incoming_cid)

idata =	incoming_call.recv_request("INVITE")
	incoming_call.send_response("100 Trying")
	incoming_call.send_response("200 OK", nil, {
		"Record-Route" => ["<sip:ec2-54-221-53-208.compute-1.amazonaws.com:5070;transport=TCP>"]+idata['message'].headers["Record-Route"],
})
	incoming_call.recv_request("ACK")  # Comes from Bono
	incoming_call.recv_request("BYE")  # Also comes from Bono

	incoming_call.send_response("200 OK", nil, {"CSeq" => "4 BYE"})
	incoming_call.end_call
