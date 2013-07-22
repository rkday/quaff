#!/usr/bin/ruby

require './sip_parser2.rb'

message = "REGISTER sips:ss2.biloxi.example.com SIP/2.0
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
Max-Forwards: 70
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 1 REGISTER
Contact: <sips:bob@client.biloxi.example.com>
Content-Length: 0"

response = "SIP/2.0 401 Unauthorized
Via: SIP/2.0/TLS client.biloxi.example.com:5061;branch=z9hG4bKnashds7
 ;received=192.0.2.201
From: Bob <sips:bob@biloxi.example.com>;tag=a73kszlfl
To: Bob <sips:bob@biloxi.example.com>;tag=1410948204
Call-ID: 1j9FpLxk3uxtm8tn@biloxi.example.com
CSeq: 1 REGISTER
WWW-Authenticate: Digest realm=\"atlanta.example.com\", qop=\"auth\",
 nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",
 opaque=\"\", stale=FALSE, algorithm=MD5
Content-Length: 0"

describe SipParser, "#parse" do
    it "does not throw an error on parsing a request" do
        parser = SipParser.new
        parser.parse_start
        parser.parse_partial message
    end

    it "does not throw an error on parsing a response" do
        parser = SipParser.new
        parser.parse_start
        parser.parse_partial response
    end

    it "produces something after parsing a request" do
        parser = SipParser.new
        parser.parse_start
        parsed = parser.parse_partial message
        parsed.should_not be nil
    end

    it "produces something from which headers can be retrieved after parsing a request" do
        parser = SipParser.new
        parser.parse_start
        parsed = parser.parse_partial message
        parsed.header("Max-Forwards").should eq ["70"]
    end

    it "produces something from which headers can be retrieved after parsing a response" do
        parser = SipParser.new
        parser.parse_start
        parsed = parser.parse_partial response
        parsed.header("CSeq").should eq ["1 REGISTER"]
    end
end
