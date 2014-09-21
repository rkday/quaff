# -*- coding: us-ascii -*-
require 'securerandom'
require_relative './sip_parser.rb'

module Quaff
  class SipDialog
    attr_accessor :local_uri, :local_tag, :peer_uri, :peer_tag, :target, :call_id, :cseq, :routeset, :established

    def initialize call_id, local_uri, peer_uri
      @cseq = 1
      @call_id = call_id
      @established = false
      @routeset = []
      @local_tag = SecureRandom::hex
      @peer_uri = peer_uri
      @target = peer_uri
      @local_uri = local_uri
    end

    def get_peer_info fromto_hdr
      tospec = ToSpec.new
      tospec.parse(fromto_hdr)
      @peer_tag = tospec.params['tag']
      @peer_uri = tospec.uri  
    end

    def local_fromto
      if @local_tag
        "<#{@local_uri}>;tag=#{@local_tag}"
      else
        "<#{@local_uri}>"      
      end
    end

    def peer_fromto
      if @peer_tag
        "<#{@peer_uri}>;tag=#{@peer_tag}"
      else
        "<#{@peer_uri}>"      
      end
    end
  end
end
