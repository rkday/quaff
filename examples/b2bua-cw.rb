require_relative '../../quaff/quaff.rb'
c = TCPSIPConnection.new(5070)

	incoming_cid = c.get_new_call_id
incoming_call = Call.new(c, incoming_cid)

idata =	incoming_call.recv_request("INVITE")
	puts "About to send 100"
	incoming_call.send_response("100 Trying")
	puts "100 sent"
def get_next_hop header
/<sip:(.+@)?(.+):(\d+);(.*)>/ =~ header
puts $2, $3
sock = TCPSocket.new $2, $3
puts sock.addr
puts sock.peeraddr
return TCPSource.new sock
end

source = get_next_hop idata['message'].headers["Route"][1]

# Send a new call back to Sprout
	outgoing_call = Call.new(c, "2///"+incoming_cid)
outgoing_call.setdest(source, recv_from_this: true)

# Copy top Route header to Route or Request-URI?
	/<sip:(.*)>/ =~ idata['message'].header("To") # Copy To, From headers etc.
	outgoing_call.set_callee($1) # Copy To, From headers etc.
	outgoing_call.send_request("INVITE", nil, nil, {
		"To" => idata['message'].header("To"),
		"From" => idata['message'].header("From")+"2",
#		"Contact" => data['message'].header("Contact"),
		"Route" => idata['message'].headers["Route"][1],
		"Record-Route" => ["<sip:ec2-54-221-53-208.compute-1.amazonaws.com:5070;transport=TCP>"]+idata['message'].headers["Record-Route"],
		"Content-Length" => "0",
})
	puts "Invite sent"
	outgoing_call.recv_response("100")
	outgoing_call.recv_response("180")
	puts "Received 180 Ringing"
	incoming_call.send_response("180 Ringing", nil, {
		"To" => idata['message'].header("To")+";tag=mytag",
		"Route" => idata['message'].headers["Route"][1],
})

	data = outgoing_call.recv_response("200")

# Switch over to talking to Bono now the dialog is established
puts data['message'].headers["Record-Route"][0]
bono = get_next_hop data['message'].headers["Record-Route"][0]
outgoing_call.setdest(bono, recv_from_this: true)
	outgoing_call.send_request("ACK", nil, nil, {
		"Contact" => data['message'].header("Contact"),
})

	incoming_call.send_response("200 OK", nil, {
		"Record-Route" => ["<sip:ec2-54-221-53-208.compute-1.amazonaws.com:5070;transport=TCP>"]+idata['message'].headers["Record-Route"],
})
	incoming_call.recv_request("ACK")  # Comes from Bono
	incoming_call.recv_request("BYE")  # Also comes from Bono

# We automatically switch to Bono now, as that's where the BYE came from
	incoming_call.send_response("200 OK")
	incoming_call.end_call

	outgoing_call.send_request("BYE")
	outgoing_call.recv_response("200")
	outgoing_call.end_call

