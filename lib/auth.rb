module Quaff
  module Auth
    def Auth.gen_nonce auth_pairs, username, passwd, method, sip_uri
      a1 = username + ":" + auth_pairs["realm"] + ":" + passwd
      a2 = method + ":" + sip_uri
      ha1 = Digest::MD5::hexdigest(a1)
      ha2 = Digest::MD5::hexdigest(a2)
      digest = Digest::MD5.hexdigest(ha1 + ":" + auth_pairs["nonce"] + ":" + ha2)
      return digest
    end

    def Auth.gen_auth_header auth_line, username, passwd, method, sip_uri
      # Split auth line on commas
      auth_pairs = {}
      auth_line.sub("Digest ", "").split(",") .each do |pair|
        key, value = pair.split "="
        auth_pairs[key.gsub(" ", "")] = value.gsub("\"", "").gsub(" ", "")
      end
      digest = gen_nonce auth_pairs, username, passwd, method, sip_uri
      return %Q!Digest username="#{username}",realm="#{auth_pairs['realm']}",nonce="#{auth_pairs['nonce']}",uri="#{sip_uri}",response="#{digest}",algorithm="#{auth_pairs['algorithm']}",opaque="#{auth_pairs['opaque']}"!
      # Return Authorization header with fields username, realm, nonce, uri, nc, cnonce, response, opaque
    end
  end
end
