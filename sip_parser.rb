require "oversip"
require "oversip/sip/sip.rb"
require "oversip/sip/sip_parser.so"
require "oversip/sip/constants.rb"
require "oversip/sip/core.rb"
require "oversip/sip/message.rb"
require "oversip/sip/request.rb"
require "oversip/sip/response.rb"
require "oversip/sip/uri.rb"
require "oversip/sip/name_addr.rb"
require "oversip/sip/message_processor.rb"
require "oversip/sip/listeners.rb"
require "oversip/sip/launcher.rb"
require "oversip/sip/server_transaction.rb"
require "oversip/sip/client_transaction.rb"
require "oversip/sip/transport_manager.rb"
require "oversip/sip/timers.rb"
require "oversip/sip/tags.rb"
require "oversip/sip/rfc3263.rb"
require "oversip/sip/client.rb"
require "oversip/sip/proxy.rb"
require "oversip/sip/uac.rb"
require "oversip/sip/uac_request.rb"

class SipParser
    def parse_start(data)
        @p = OverSIP::SIP::MessageParser.new
        @nread = 0
        @buf = ""
        @msg = nil
        parse_partial data
    end

    def parse_partial(data)
        @buf << data
        if not @p.finished? then
            @nread = @p.execute(@buf,@nread)
            if @p.finished?
                if @p.parsed.header("Content-Length").to_i == 0 then
                    return @p.parsed
                elsif data.index("\r\n\r\n") then
                    msg = @p.parsed
                    msg.body = data.split("\r\n\r\n")[1]
                    return msg
                else
                    return nil
                end
            else
                return nil
            end
        else
            @p.post_parsing
            @msg ||= @p.parsed
            body_len = @msg.header("Content-Length").to_i

            if @msg.body.nil?
                @msg.body = ""
            end

            if data.index("\r\n\r\n") then
                @msg.body = data.split("\r\n\r\n")[1]
            else
                @msg.body << data
            end

            if @msg.body.to_s.length >= body_len
                return @msg
            else
                return nil
            end
        end
    end

    def message_identifier(msg)
        msg.header "Call-ID"
    end

end

