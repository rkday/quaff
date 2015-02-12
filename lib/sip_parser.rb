# -*- coding: us-ascii -*-
require 'digest/md5'
require 'abnf'
require_relative './message.rb'

# The valid states for the parser:
# :blank
# :parsing_headers
# :waiting_for_body
# :done

module Quaff
  class SipParser # :nodoc:
    attr_reader :state
    def initialize
      @state = :blank
      @msg = SipMessage.new
    end

    def parse_from_io(io, udp=false)
      parse_start

      parse_initial_line(io.gets.rstrip)
      while @state == :parsing_headers and not io.closed? do
        parse_header_line io.gets.rstrip
      end

      if io.closed?
        raise "Socket closed unexpectedly!"
      end

      if @state == :waiting_for_body
        body = io.read(body_length)
        add_body body
      elsif udp and msg.header("Content-Length").nil?
        add_body io.read(1500)
      end        
      @msg
    end

    def parse_start
      @msg = SipMessage.new
      @state = :blank
    end

    def message_identifier(msg)
      msg.header("Call-ID")
    end

    def body_length
      if @msg.header("Content-Length")
        @msg.header("Content-Length").to_i
      else
        0
      end
    end

    def parse_initial_line line
      fail "Invalid state: #{@state}" unless @state == :blank
      parts = line.split " ", 3
      if parts[2] == "SIP/2.0"
        # Looks like a SIP request
        @msg.method = parts[0]
        @msg.requri = parts[1]
      elsif parts[0] == "SIP/2.0"
        # Looks like a SIP response
        @msg.status_code = parts[1]
        @msg.reason = parts[2] || ""
      else
        raise parts.inspect
      end
      @state = :parsing_headers
    end

    def process_continuation_line line
        @msg.headers[@cur_hdr][-1] += " "
        @msg.headers[@cur_hdr][-1] += line.lstrip
    end
    
    def parse_header_line line
      fail "Invalid state: #{@state}" unless @state == :parsing_headers
      if line == "" and (body_length == 0)
        @state = :done
      elsif line == ""
        @state = :waiting_for_body
      elsif line.start_with? " "
        process_continuation_line line
      elsif line.include? ":"
        parts = line.split ":", 2
        header_name, header_value = parts[0].rstrip, parts[1].lstrip
        @msg.headers[header_name] ||= []
        @msg.headers[header_name].push header_value

        if header_name == "Content-Length"
          # Special treatment - Content-Length defaults to 0 at
          # creation, so has to be overwritten
          @msg.headers[header_name] = [header_value]
        end

        @cur_hdr = header_name
      else
        raise line.inspect
      end
    end

    def add_body body
      fail "Invalid state: #{@state}" unless (@state == :waiting_for_body || @state == :done)
      @msg.body = body
      @state = :done
    end

    def msg
      fail "Invalid state: #{@state}" unless @state == :done
      @msg
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

    def tel_uri
      Concat.new(Literal.new("tel:"),
                 Repetition.new([:at_least, 1], Digit.new))
    end

    def addr_spec
      Alternate.new(sip_uri, tel_uri)
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
