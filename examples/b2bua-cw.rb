require_relative '../../quaff/quaff.rb'
c = TCPSIPConnection.new(5070)

	incoming_cid = c.get_new_call_id
incoming_call = Call.new(c, incoming_cid)

	incoming_call.recv_request("INVITE")
	incoming_call.send_response("100")

# Send a new call back to Sprout
	outgoing_call = Call.new(c, call_id: incoming_cid+"///2")
outgoing_call.setdest(incoming_call.get_next_hop_from_route, recv_from_this: true)

# Copy top Route header to Route or Request-URI?
	outgoing_call.clone_details(incoming_call) # Copy To, From headers etc.
	outgoing_call.send_request("INVITE")

	outgoing_call.recv_response("180")
	incoming_call.send_response("180")

	outgoing_call.recv_response("200")

# Switch over to talking to Bono now the dialog is established
outgoing_call.setdest(outgoing_call.get_next_hop_from_rr)
	outgoing_call.send_request("ACK")

	incoming_call.send_response("200 OK", false, nil, {"Contact" => mock_as})
	incoming_call.recv_request("ACK")  # Comes from Bono
	incoming_call.recv_request("BYE")  # Also comes from Bono

# We automatically switch to Bono now, as that's where the BYE came from
	incoming_call.send_response("200 OK")
	incoming_call.end_call

	outgoing_call.send_request("BYE")
	outgoing_call.recv_response("200")
	outgoing_call.end_call

