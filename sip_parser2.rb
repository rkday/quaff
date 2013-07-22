require 'digest/md5'

class SipMessage
    attr_accessor :type, :method, :requri, :reason, :status_code, :headers

    def initialize
        @headers = {}
        @method, @status_code, @reason, @req_uri, @body = nil
    end

    def header hdr
        return @headers[hdr]
    end
end

class SipParser
    def parse_start
        @buf = ""
        @msg = SipMessage.new
        @state = :blank
    end

    def parse_partial(data)
        @buf << data
        @buf.lines.each do |line|
            if @state == :blank
                parse_line_blank line
            elsif @state == :first_line_parsed
                parse_line_first_line_parsed line
            elsif @state == :middle_of_headers
                parse_line_first_line_parsed line
            elsif @state == :got_content_length
                return @msg
            elsif @state == :parsing_body
            end
        end
        @msg
    end

    def message_identifier(msg)
        msg.header "Call-ID"
    end

    def parse_line_blank line
        if line =~ %r!^([A-Z]+) (.+) SIP/2.0$!
            @msg.type = :request
            @msg.method = $1
            @msg.requri = $2
            @state = :first_line_parsed
        elsif line =~ %r!^SIP/2.0 (\d+) (.+)$!
            @msg.type = :response
            @msg.status_code = $1
            @msg.reason = $2
            @state = :first_line_parsed
        elsif line == ""
        else
            raise line
        end
    end

    def parse_line_first_line_parsed line
        if line =~ /^\s+(.+)/
            @msg.headers[@cur_hdr][-1] += " "
            @msg.headers[@cur_hdr][-1] += $1
        elsif line =~ /^([-\w]+)\s*:\s*(.+)/
            @msg.headers[$1] ||= []
            @msg.headers[$1].push $2
            @cur_hdr = $1
            if $1 == "Content-Length"
            @state = :got_content_length 
            else
                @state = :middle_of_headers
            end
        else raise line
        end
    end
end

def gen_nonce auth_line, username, passwd, method, sip_uri         
    # Split auth line on commas
    auth_pairs = {}
    auth_line.sub("Digest ", "").split(",") .each do |pair| 
        key, value = pair.split "="
        auth_pairs[key.gsub(" ", "")] = value.gsub("\"", "").gsub(" ", "")
    end
    puts auth_pairs
    a1 = username + ":" + auth_pairs["realm"] + ":" + passwd
    a2 = method + ":" + sip_uri
    ha1 = Digest::MD5::hexdigest(a1)
    ha2 = Digest::MD5::hexdigest(a2)
    puts a1
    puts ha1
    puts a2
    puts ha2
    puts auth_pairs["nonce"]
    digest = Digest::MD5.hexdigest(ha1 + ":" + auth_pairs["nonce"] + ":" + ha2)
    puts digest
    return digest
end

def authenticate auth_line, username, passwd, method, sip_uri
    digest = gen_nonce auth_line, username, passwd, method, sip_uri         
    return "username=#{username}, realm=#{auth_pairs['realm']}, nonce=#{auth_pairs['nonce']}, uri=#{sip_uri}, response=#{digest}, opaque=#{auth_pairs['opaque']}"
    # Return Authorization header with fields username, realm, nonce, uri, nc, cnonce, response, opaque
end
