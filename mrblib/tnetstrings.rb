class String
  unless method_defined? :byteslice
  #
  # Does the same thing as String#slice but
  # operates on bytes instead of characters.
  #
    def byteslice(*args)
      unpack('C*').slice(*args).pack('C*')
    end
  end
end

# Copyright (c) 2014 Alex Brem

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module TNetStrings
  def self.dump(data)
    case data
      when String then "#{data.bytesize}:#{data.bytes.pack('C*')},"
      when Symbol then "#{data.to_s.length}:#{data.to_s},"
      when Fixnum  then "#{data.to_s.length}:#{data.to_s}#"
      when Float then "#{data.to_s.length}:#{data.to_s}^"
      when TrueClass then "4:true!"
      when FalseClass then "5:false!"
      when NilClass then "0:~"
      when Array then dump_array(data)
      when Hash then dump_hash(data)
    else
      if data.respond_to?(:to_s)
        s = data.to_s
        "#{s.length}:#{s},"
      else
        raise "Can't serialize stuff that's '#{data.class}'."
      end
    end
  end

  def self.parse(data)
    raise "Invalid data." if data.empty?
    payload, payload_type, remain = parse_payload(data)

    value = case payload_type
      when ',' then payload
      when '#' then payload.to_i
      when '^' then payload.to_f
      when '!' then payload == 'true'
      when ']' then parse_array(payload)
      when '}' then parse_hash(payload)
      when '~'
        raise "Payload must be 0 length for null." unless payload.length == 0
        nil
      else
        raise "Invalid payload type: #{payload_type}"
    end

    [ value, remain ]
  end

  def self.parse_payload(data)
    raise "Invalid payload type: #{payload_type}" if data.empty?

    len, extra = data.split(':', 2)
    len = len.to_i
    if len == 0
      payload = ''
    else
      payload, extra = extra.byteslice(0..len-1), extra.byteslice(len..-1)
    end
    payload_type, remain = extra[0], extra[1..-1]

    [ payload, payload_type, remain ]
  end

  private

  def self.parse_array(data)
    arr = []
    return arr if data.empty?

    begin
      value, data = parse(data)
      arr << value
    end while not data.empty?

    arr
  end

  def self.parse_pair(data)
    key, extra = parse(data)
    raise "Unbalanced hash" if extra.empty?
    value, extra = parse(extra)

    [ key, value, extra ]
  end

  def self.parse_hash(data)
    hsh = {}
    return hsh if data.empty?

    begin
      key, value, data = parse_pair(data)
      hsh[key.to_sym] = value
    end while not data.empty?

    hsh
  end

  def self.dump_array(data)
    payload = ""
    data.each { |v| payload << dump(v) }
    "#{payload.length}:#{payload}]"
  end

  def self.dump_hash(data)
    payload = ""
    data.each do |k,v|
      payload << dump(k.to_s)
      payload << dump(v)
    end
    "#{payload.length}:#{payload}}"
  end
end
