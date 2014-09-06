#!/usr/bin/ruby

require 'quaff'

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

response = force_crlf("SIP/2.0 401 Unauthorized
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

describe Quaff::SipParser do
  before :all do
    @parser = Quaff::SipParser.new
    @parser.parse_start
    @parsed_request = @parser.parse_partial message
    @parser.parse_start
    @parsed_response = @parser.parse_partial response
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

  it "correctly handles headers with multiple values" do
    expect(@parsed_request.all_headers("Contact")).to eq(["<sips:bob@client.biloxi.example.com>", "<sips:bob2@client.biloxi.example.com>"])
  end

  it "produces something from which headers can be retrieved after parsing a response" do
    expect(@parsed_response.header("CSeq")).to eq("1 REGISTER")
    expect(@parsed_response.header("Content-Length")).to eq("0")
  end
end
