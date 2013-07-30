require_relative '../../quaff/quaff.rb'
c = TCPSIPConnection.new(5070)

	incoming_cid = c.get_new_call_id
incoming_call = Call.new(c, incoming_cid)

data =	incoming_call.recv_request("INVITE")
	puts "About to send 100"
	incoming_call.send_response("100")
	puts "100 sent"
/<sip:.+@(.+):(\d+);lr>/ =~ data['message'].headers["Route"][1]
puts $1, $2
sock = TCPSocket.new $1, $2
puts sock
source = TCPSource.new sock

# Send a new call back to Sprout
	outgoing_call = Call.new(c, incoming_cid+"///2")
outgoing_call.setdest(source, recv_from_this: true)

# Copy top Route header to Route or Request-URI?
	/<sip:(.*)>/ =~ data['message'].header("To") # Copy To, From headers etc.
	outgoing_call.set_callee($1) # Copy To, From headers etc.
	outgoing_call.send_request("INVITE", nil, {
		To: data['message'].header("To"),
		From: data['message'].header("From"),
		Route: data['message'].header("Route"),
})
	puts "Invite sent"
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

