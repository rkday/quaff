class SipMessage
    def initialize
        @headers = {}
        @method, @status_code, @reason, @req_uri, @body = nil

class SipParser
    def parse_start(data)
        @buf = ""
        msg = SipMessage.new
    end

    def parse_partial(data)
        @buf << data
        @buf.lines.each do |line|
            if @state == :blank
            elsif @state == :first_line_parsed
            elsif @state == :middle_of_headers
            elsif @state == :got_content_length
            elsif @state == :parsing_body
            end
        end
    end

    def message_identifier(msg)
        msg.header "Call-ID"
    end

    def parse_line_blank line
        if line =~ "([A-Z]+) (.+) SIP/2.0"
            msg.type = :request
            msg.method = $1
            msg.requri = $2
        elsif line =~ "SIP/2.0 (\d+) (.+)"
            msg.type = :response
            msg.status_code = $1
            msg.reason = $2
        elsif line = ""
        else raise
        end
    end

    def parse_line_first_line_parsed line
        if line =~ /(\w+)\s*:\s*(.+)/
            msg.headers[$1] ||= []
            msg.headers[$1].push $2
            @cur_hdr = $1
            @state = :got_content_length if $1 == "Content-Length" else :middle_of_headers
        elsif line =~ /\s+(.+)/
            msg.headers[@cur_hdr][-1] += $1
        end
    end
