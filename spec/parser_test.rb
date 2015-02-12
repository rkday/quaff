#!/usr/bin/ruby

require 'quaff'
require 'stringio'

def force_crlf text
  text.gsub(/\n/, "\r\n")
end

message = force_crlf("REGISTER sips:ss2.biloxi.example.com SIP/2.0
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
Max-Forwards: 70
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 1 REGISTER
Contact: <sips:bob@client.biloxi.example.com>
Contact: <sips:bob2@client.biloxi.example.com>
Content-Length: 0

")

response = force_crlf("SIP/2.0 402 Unauthorized
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
 ;received=192.0.2.201
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>;tag=1410948204
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 1 REGISTER
WWW-Authenticate: Digest realm=\"atlanta.example.com\", qop=\"auth\",
 nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",
 opaque=\"\", stale=FALSE, algorithm=MD5
Content-Length: 0

")

responses_combined = force_crlf("SIP/2.0 403 Unauthorized
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
 ;received=192.0.2.201
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>;tag=1410948204
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 1 REGISTER
WWW-Authenticate: Digest realm=\"atlanta.example.com\", qop=\"auth\",
 nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",
 opaque=\"\", stale=FALSE, algorithm=MD5
Content-Length: 4

abcdSIP/2.0 404 Unauthorized
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
 ;received=192.0.2.201
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>;tag=1410948204
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 100 REGISTER
WWW-Authenticate: Digest realm=\"atlanta.example.com\", qop=\"auth\",
 nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",
 opaque=\"\", stale=FALSE, algorithm=MD5
Content-Length: 0

")

describe Quaff::SipParser do
  before :all do
    @parser = Quaff::SipParser.new
    
    @parsed_request = @parser.parse_from_io(StringIO.new(message))

    @parsed_response = @parser.parse_from_io(StringIO.new(response))

    combined_io = StringIO.new(responses_combined)

    @parsed_response_combined = @parser.parse_from_io(combined_io)
    @parsed_response_combined_2 = @parser.parse_from_io(combined_io)
  end

  it "produces something after parsing a request" do
    expect(@parser.state).to eq(:done)
    expect(@parsed_request).not_to eq(nil)
  end

  it "produces something from which headers can be retrieved after parsing a request" do
    expect(@parsed_request.header("CSeq")).to eq("1 REGISTER")
  end

  it "can parse headers with a hyphen" do
    expect(@parsed_request.header("Max-Forwards")).to eq("70")
  end

  it "can parse bodies not ending in CRLF" do
    expect(@parsed_response_combined.body).to eq("abcd")
    expect(@parsed_response_combined_2.header("CSeq")).to eq("100 REGISTER")
  end

  it "correctly handles headers with multiple values" do
    expect(@parsed_request.all_headers("Contact")).to eq(["<sips:bob@client.biloxi.example.com>", "<sips:bob2@client.biloxi.example.com>"])
  end

  it "produces something from which headers can be retrieved after parsing a response" do
    expect(@parsed_response.header("CSeq")).to eq("1 REGISTER")
    expect(@parsed_response.header("Content-Length")).to eq("0")
  end

  it "produces something from which headers can be retrieved after parsing a response" do
    expect(@parsed_response.header("CSeq")).to eq("1 REGISTER")
    expect(@parsed_response.header("Content-Length")).to eq("0")
  end
end

describe Quaff::ToSpec do
  it "parses a header into component parts" do
    header = '"Alice" <sip:alice@example.com;transport=TCP>;tag=abcd'
    to = Quaff::ToSpec.new
    expect(to.parse header).to eq(true)
    expect(to.displayname).to eq('"Alice"')
    expect(to.is_nameaddr).to eq(true)
    expect(to.uri).to eq("sip:alice@example.com;transport=TCP")
    expect(to.params['tag']).to eq("abcd")
    expect(to.to_s).to eq(header)
  end

  it "parses a basic header into component parts" do
    header = 'sip:alice@example.com'
    to = Quaff::ToSpec.new
    expect(to.parse header).to eq(true)
    expect(to.displayname).to eq(nil)
    expect(to.is_nameaddr).to eq(false)
    expect(to.uri).to eq("sip:alice@example.com")
    expect(to.params['tag']).to eq(nil)
    expect(to.to_s).to eq(header)
  end

  it "parses a header with dashes into component parts" do
    header = '"Alice" <sip:alice@example-no-2.com;transport=TCP>;tag=abcd'
    to = Quaff::ToSpec.new
    expect(to.parse header).to eq(true)
    expect(to.displayname).to eq('"Alice"')
    expect(to.is_nameaddr).to eq(true)
    expect(to.uri).to eq("sip:alice@example-no-2.com;transport=TCP")
    expect(to.params['tag']).to eq("abcd")
    expect(to.to_s).to eq(header)
  end

  it "parses a tel: URI" do
    header = '"Alice" <tel:1234>;tag=abcd'
    to = Quaff::ToSpec.new
    expect(to.parse header).to eq(true)
    expect(to.uri).to eq("tel:1234")
  end

end
