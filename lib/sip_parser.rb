# -*- coding: us-ascii -*-
require 'digest/md5'
require_relative './message.rb'

module Quaff
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
        line.rstrip!
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
      if line == ""
        # skip empty lines
        return
      else
        parts = line.split " ", 3
        if parts[2] == "SIP/2.0"
          # Looks like a SIP request
          @msg.method = parts[0]
          @msg.requri = parts[1]
          @state = :first_line_parsed
          return
        elsif parts[0] == "SIP/2.0"
          # Looks like a SIP response
          @msg.status_code = parts[1]
          @msg.reason = parts[2] || ""
          @state = :first_line_parsed
          return
        else
          raise parts.inspect
        end
      end
      # We haven't returned, so looks like a malformed line
      raise line.inspect
    end

    def parse_line_first_line_parsed line
      if line.start_with? " "
        @msg.headers[@cur_hdr][-1] += " "
        @msg.headers[@cur_hdr][-1] += line.lstrip
      elsif line.include? ":"
        parts = line.split ":", 2
        header_name, header_value = parts[0].rstrip, parts[1].lstrip
        @msg.headers[header_name] ||= []
        @msg.headers[header_name].push header_value
        @cur_hdr = header_name
        if header_name == "Content-Length"
          @state = :got_content_length
          @msg.headers[header_name] = [header_value]
        else
          if (@state != :got_content_length)
            @state = :middle_of_headers
          end
        end
      elsif line == ""
        if (@state == :got_content_length) and (@msg.header("Content-Length").to_i > 0)
          @state = :parsing_body
        else
          @state = :done
        end
      else raise line.inspect
      end
    end

    def parse_line_body line
      @msg.body << line
      @msg.body << "\r\n"
      if line == "" or @msg.body.length >= @msg.header("Content-Length").to_i
        @state = :done
      end
    end

  end

end
