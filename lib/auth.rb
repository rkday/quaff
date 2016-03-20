require 'base64'

module Quaff
  module Auth #:nodoc:
    def Auth.gen_nonce auth_pairs, username, passwd, method, sip_uri, ha1="", qop="", nc=1, cnonce=""
      if ha1.empty?
        a1 = username + ":" + auth_pairs["realm"] + ":" + passwd
        ha1 = Digest::MD5::hexdigest(a1)
      end
      a2 = method + ":" + sip_uri
      ha2 = Digest::MD5::hexdigest(a2)
      if qop == "auth"
        digest = Digest::MD5.hexdigest(ha1 + ":" + auth_pairs["nonce"] + ":" + nc.to_s(16).rjust(8, "0") + ":" + cnonce + ":" + qop + ":" + ha2)
      else
        digest = Digest::MD5.hexdigest(ha1 + ":" + auth_pairs["nonce"] + ":" + ha2)
      end
      return digest
    end

    def Auth.extract_rand auth_line
      # Split auth line on commas
      auth_pairs = {}
      auth_line.sub("Digest ", "").split(",") .each do |pair|
        key, value = pair.split "="
        auth_pairs[key.gsub(" ", "")] = value.gsub("\"", "").gsub(" ", "")
      end
      # First 128 bits are the RAND
      return Base64.decode64(auth_pairs["nonce"])[0..15]
    end

    def Auth.gen_empty_auth_header username
      return %Q!Digest username="#{username}",realm="",nonce="",uri="",response=""!
      # Return Authorization header with only the username field set,
      # to indicate the private ID in cases where it isn't linked to
      # the SIP URI
    end

    def Auth.gen_auth_header auth_line, username, passwd, method, sip_uri, ha1="", qop="", nc=1, cnonce=""
      # Split auth line on commas
      auth_pairs = {}
      auth_line.sub("Digest ", "").split(",") .each do |pair|
        key, value = pair.split "="
        auth_pairs[key.gsub(" ", "")] = value.gsub("\"", "").gsub(" ", "")
      end
      if !qop.empty? and cnonce.empty?
        cnonce = (0...16).map { (rand(16)).to_s(16) }.join
      end
      digest = gen_nonce auth_pairs, username, passwd, method, sip_uri, ha1, qop, nc, cnonce
      if !qop.empty?
        return %Q!Digest username="#{username}",realm="#{auth_pairs['realm']}",nonce="#{auth_pairs['nonce']}",uri="#{sip_uri}",response="#{digest}",algorithm="#{auth_pairs['algorithm']}",opaque="#{auth_pairs['opaque']}",qop="#{qop}",nc="#{nc.to_s(16).rjust(8, "0")}",cnonce="#{cnonce}"!
      else
        return %Q!Digest username="#{username}",realm="#{auth_pairs['realm']}",nonce="#{auth_pairs['nonce']}",uri="#{sip_uri}",response="#{digest}",algorithm="#{auth_pairs['algorithm']}",opaque="#{auth_pairs['opaque']}"!
      end
      # Return Authorization header with fields username, realm, nonce, uri, nc, cnonce, response, opaque
    end
  end
end
