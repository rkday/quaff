# -*- coding: us-ascii -*-
require 'digest/md5'

class SipMessage
    attr_accessor :type, :method, :requri, :reason, :status_code, :headers, :body

    def initialize
        @headers = {}
        @method, @status_code, @reason, @req_uri = nil
        @body = ""
    end

    def all_headers hdr
        return @headers[hdr]
    end

    def header hdr
        return @headers[hdr][0] unless @headers[hdr].nil?
    end

    alias_method :first_header, :header

    def to_s
       "#{@method} #{@status_code} #{@headers}"
    end

end

  class SipParser
    attr_reader :state
    def parse_start
        @buf = ""
        @msg = SipMessage.new
        @state = :blank
    end

    def parse_partial(data)
        return nil if data.nil?
        data.lines.each do |line|
            if @state == :blank
                parse_line_blank line
            elsif @state == :parsing_body
                parse_line_body line
            else
                parse_line_first_line_parsed line
            end
        end
            if @state == :done
                return @msg
            else
                return nil
            end
    end

    def message_identifier(msg)
        msg.header("Call-ID")
    end

    def parse_line_blank line
        if line =~ %r!^([A-Z]+) (.+) SIP/2.0\r$!
            @msg.type = :request
            @msg.method = $1
            @msg.requri = $2
            @state = :first_line_parsed
        elsif line =~ %r!^SIP/2.0 (\d+) (.+)\r$!
            @msg.type = :response
            @msg.status_code = $1
            @msg.reason = $3 || ""
            @state = :first_line_parsed
        elsif line == "\r" or line == "\r\n"
            # skip empty lines
        else
            raise line.inspect
        end
    end

    def parse_line_first_line_parsed line
        if line =~ /^\s+(.+)\r/
            @msg.headers[@cur_hdr][-1] += " "
            @msg.headers[@cur_hdr][-1] += $1
            if $1 == "Content-Length"
                @state = :got_content_length
            else
                @state = :middle_of_headers
            end
        elsif line =~ /^([-\w]+)\s*:\s*(.+)\r/
            @msg.headers[$1] ||= []
            @msg.headers[$1].push $2
            @cur_hdr = $1
            if $1 == "Content-Length"
                @state = :got_content_length
            else
                @state = :middle_of_headers
            end
        elsif line == "\r" or line == "\r\n"
            if @state == :got_content_length and @msg.header("Content-Length").to_i > 0
               @state = :parsing_body
            else
               @state = :done
            end
        else raise line.inspect
        end
    end

    def parse_line_body line
       @msg.body << line
       if line == "\r" or @msg.body.length >= @msg.header("Content-Length").to_i
         @state = :done
       end
    end

end

  def gen_nonce auth_pairs, username, passwd, method, sip_uri         
    a1 = username + ":" + auth_pairs["realm"] + ":" + passwd
    a2 = method + ":" + sip_uri
    ha1 = Digest::MD5::hexdigest(a1)
    ha2 = Digest::MD5::hexdigest(a2)
    digest = Digest::MD5.hexdigest(ha1 + ":" + auth_pairs["nonce"] + ":" + ha2)
    return digest
  end

  def gen_auth_header auth_line, username, passwd, method, sip_uri
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
