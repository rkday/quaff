#!/usr/bin/ruby

require 'quaff'

describe Quaff::UDPSIPEndpoint do
  it "allows the instance-id to be set" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    ep.instance_id = "abcde"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>;\+sip\.instance="<urn:uuid:abcde>"/)
  end

  it "allows the instance-id to be reset" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    ep.instance_id = "abcd"
    ep.instance_id = "abcde"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>;\+sip\.instance="<urn:uuid:abcde>"/)
  end

  it "allows other header parameters to be set" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    ep.add_contact_param "+sip.phone", true
    ep.add_contact_param "pub-gruu", "goldfish"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>;\+sip\.phone;pub-gruu=goldfish$/)
  end

  it "allows Contact URI parameters to be set" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    ep.add_contact_uri_param "arbitrary-param", '"</uri>"'
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob;arbitrary-param="<\/uri>">$/)
  end

  it "allows other header parameters to be unset" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    ep.add_contact_param "+sip.phone", true
    ep.add_contact_param "pub-gruu", "goldfish"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>;\+sip\.phone;pub-gruu=goldfish$/)
    ep.remove_contact_param "pub-gruu"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>;\+sip\.phone$/)
  end

  it "allows Contact URI parameters to be unset" do
    ep = Quaff::UDPSIPEndpoint.new "sip:test@example.com", nil, nil, :anyport
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP;ob>$/)
    ep.remove_contact_uri_param "ob"
    expect(ep.contact_header).to match(/<sip:quaff@(\d+\.){3}\d+:\d+;transport=UDP>$/)
  end
end
