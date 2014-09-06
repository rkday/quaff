#!/usr/bin/ruby

require 'quaff'

describe Quaff::Auth do
  it "correctly handles authentication" do
    digest_header = "Digest realm=\"atlanta.example.com\", qop=\"auth\", nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\", opaque=\"\", stale=FALSE, algorithm=MD5"
    quaff_generated_auth_header = Quaff::Auth.gen_auth_header(digest_header, "bob", "zanzibar", "REGISTER", "sips:ss2.biloxi.example.com")
    expect(quaff_generated_auth_header).to eq("Digest username=\"bob\",realm=\"atlanta.example.com\",nonce=\"ea9c8e88df84f1cec4341ae6cbe5a359\",uri=\"sips:ss2.biloxi.example.com\",response=\"b5f508175c6cccc6f0600285b4391fbf\",algorithm=\"MD5\",opaque=\"\"")
  end
end
