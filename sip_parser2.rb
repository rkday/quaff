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
        if line =~ %r!([A-Z]+) (.+) SIP/2.0!
            @msg.type = :request
            @msg.method = $1
            @msg.requri = $2
            @state = :first_line_parsed
        elsif line =~ %r!SIP/2.0 (\d+) (.+)!
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
        if line =~ /([-\w]+)\s*:\s*(.+)/
            @msg.headers[$1] ||= []
            @msg.headers[$1].push $2
            @cur_hdr = $1
            if $1 == "Content-Length"
            @state = :got_content_length 
            else
                @state = :middle_of_headers
            end
        elsif line =~ /\s+(.+)/
            @msg.headers[@cur_hdr][-1] += $1
        end
    end
end
