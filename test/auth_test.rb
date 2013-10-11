#!/usr/bin/ruby

require 'quaff'

describe Quaff::Auth do
    it "correctly handles authentication" do
        auth_header = "Digest realm=\"atlanta.example.com\", qop=\"auth\", nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\", opaque=\"\", stale=FALSE, algorithm=MD5"
        Quaff::Auth.gen_auth_header(auth_header, "bob", "zanzibar", "REGISTER", "sips:ss2.biloxi.example.com").should eq "Digest username=\"bob\",realm=\"atlanta.example.com\",nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",uri=\"sips:ss2.biloxi.example.com\",response=\"b5f508175c6cccc6f0600285b4391fbf\",algorithm=\"MD5\",opaque=\"\""
  end
  end
