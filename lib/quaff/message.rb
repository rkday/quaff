module Quaff
class SipMessage
  attr_accessor :method, :requri, :reason, :status_code, :headers, :source
  attr_reader :body

  def initialize method=nil, status_code=nil, reason=nil,
    req_uri=nil, body="", headers={}
    @headers = headers
    @method, @status_code, @reason, @requri = method, status_code, reason, req_uri
    @body = body
    @headers['Content-Length'] = [body.length.to_s]
  end

  def [] key
    if key == "message"
      self
    elsif key == "source"
      @source
    end
  end

  def type
    if @method
      :request
    elsif @status_code
      :response
    else
      :nil
    end
  end

  def all_headers hdr
    return @headers[hdr]
  end

  def header hdr
    return @headers[hdr][0] unless @headers[hdr].nil?
  end

  alias_method :first_header, :header

  def body= body
    @body = body
    @headers['Content-Length'] = [body.length]
  end

  def to_s
    msg = ""
    if type == :request
      msg << "#{@method} #{@requri} SIP/2.0\r\n"
    else
      msg << "SIP/2.0 #{@status_code} #{@reason}\r\n"
    end

    @headers.each do |key, value|
      if value.nil?
      elsif not value.kind_of? Array
        msg << "#{key}: #{value}\r\n"
      else value.each do |subvalue|
          msg << "#{key}: #{subvalue}\r\n"
        end
      end
    end
    if body and body != ""
      msg << "\r\n"
      msg << body
    else
      msg << "\r\n"
    end


    msg
  end

end
end
