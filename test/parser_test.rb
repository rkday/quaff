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

describe SipParser, "#parse" do
    before :all do
        @parser = SipParser.new
        @parser.parse_start
        @parsed_request = @parser.parse_partial message
        @parser.parse_start
        @parsed_response = @parser.parse_partial response
    end

  it "produces something after parsing a request" do
    @parser.state.should eq :done
    @parsed_request.should_not be nil
    end

    it "produces something from which headers can be retrieved after parsing a request" do
        @parsed_request.header("CSeq").should eq "1 REGISTER"
    end

    it "can parse headers with a hyphen" do
        @parsed_request.header("Max-Forwards").should eq "70"
    end

    it "correctly handles headers with multiple values" do
        @parsed_request.all_headers("Contact").should eq ["<sips:bob@client.biloxi.example.com>", "<sips:bob2@client.biloxi.example.com>"]
    end

    it "produces something from which headers can be retrieved after parsing a response" do
        @parsed_response.header("CSeq").should eq "1 REGISTER"
        @parsed_response.header("Content-Length").should eq "0"
    end

    it "correctly handles authentication" do
        @parsed_response.header("WWW-Authenticate").should eq "Digest realm=\"atlanta.example.com\", qop=\"auth\", nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\", opaque=\"\", stale=FALSE, algorithm=MD5"
        gen_auth_header(@parsed_response.header("WWW-Authenticate"), "bob", "zanzibar", "REGISTER", "sips:ss2.biloxi.example.com").should eq "Digest username=\"bob\",realm=\"atlanta.example.com\",nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",uri=\"sips:ss2.biloxi.example.com\",response=\"b5f508175c6cccc6f0600285b4391fbf\",algorithm=\"MD5\",opaque=\"\""
    end

end
