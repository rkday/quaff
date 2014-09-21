# -*- coding: us-ascii -*-
require 'digest/md5'
require 'abnf'
require_relative './message.rb'

module Quaff
  class SipParser # :nodoc:
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

  class ABNFSipParser # :nodoc:
    include ABNF

    # Rules

    def alphanum
      Alternate.new(Alpha.new, Digit.new)
    end

    def reserved
      AlternateChars.new(";/?:@&=+$,")
    end

    def mark
      AlternateChars.new("-_.!~*'()")
    end

    def unreserved
      Alternate.new(alphanum, mark)
    end

    def escaped
      Concat.new(Char.new(?%), HexDigit.new, HexDigit.new)
    end

    def user_unreserved
      AlternateChars.new "&=+$,;?/"
    end

    def user
      Repetition.new([:at_least, 1], Alternate.new(unreserved, escaped, user_unreserved))
    end

    def userinfo
      Concat.new(user, Char.new(?@))
    end

    def hostname
      Repetition.new([:at_least, 1], Alternate.new(alphanum, Char.new(?.), Char.new(?-)))
    end

    def port
      Repetition.new([:at_least, 1], Digit.new)
    end

    def hostport
      Concat.new(hostname, OptionalConcat.new(Char.new(?:), port))
    end

    def paramchar
      paramunreserved = AlternateChars.new("[]/:&+%")
      Alternate.new(paramunreserved, unreserved, escaped)
    end

    def pname
      Repetition.new([:at_least, 1], paramchar)
    end

    def pvalue
      Repetition.new([:at_least, 1], paramchar)
    end


    def param
      Concat.new(pname, OptionalConcat.new(Char.new(?=), pvalue))
    end

    def uri_parameters
      Repetition.new(:any,
                     Concat.new(Char.new(?;), param))
    end

    def sip_uri
      Concat.new(Literal.new("sip:"),
                 Optional.new(userinfo),
                 hostport,
                 uri_parameters)
    end

    def addr_spec
      sip_uri
    end

    def wsp
      Alternate.new(Char.new(" "), Char.new("\t"))
    end

    def lws
      Concat.new(OptionalConcat.new(Repetition.new([:at_least, 1], wsp), Literal.new("\r\n")), Repetition.new([:at_least, 1], wsp))
    end

    def sws
      Optional.new(lws)
    end

    def raquot
      Concat.new(Char.new(">"), sws)
    end

    def laquot
      Concat.new(sws, Char.new("<"))
    end

    def display_name
      Repetition.new(:any, Alternate.new(alphanum, wsp, Char.new(?")))
    end

    def name_addr
      Concat.new(display_name, laquot, addr_spec, raquot)
    end

    def from_param
      param
    end

    def from_spec
      Concat.new(Alternate.new(addr_spec, name_addr), Repetition.new(:any, Concat.new(Char.new(?;), from_param)))
    end

    def to_param
      param
    end

    def to_spec
      Concat.new(Alternate.new(addr_spec, name_addr), Repetition.new(:any, Concat.new(Char.new(?;), to_param)))
    end
  end

  class ToSpec < ABNFSipParser # :nodoc:
    attr_accessor :params, :uri, :displayname, :is_nameaddr
    def initialize
      super
      @params = {}
      @uri = nil
      @displayname = nil
      @is_nameaddr = false
    end

    def to_param
      super.set_block {|p| k, v = p.split("="); @params[k] = if v.nil? then true else v end}
    end

    def display_name
      super.set_block {|p| @displayname = p.strip; @is_nameaddr = true}
    end

    def addr_spec
      super.set_block {|p| @uri = p}
    end

    def parse(str)
      if to_spec.match(Stream.new(str))
        true
      else
        false
      end
    end

    def to_s
      paramstr = Utils.paramhash_to_str(@params)
      if @is_nameaddr
        "#{@displayname} <#{@uri}>#{paramstr}"
      else
        "#{@uri}#{paramstr}"
      end
    end
  end

end
