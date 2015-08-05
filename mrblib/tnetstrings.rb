class String
  unless method_defined? :byteslice
  #
  # Does the same thing as String#slice but
  # operates on bytes instead of characters.
  #
  CSTAR = 'C*'

    def byteslice(*args)
      unpack(CSTAR).slice(*args).pack(CSTAR)
    end
  end
end

# Copyright (c) 2011 Matt Yoho

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
  class ProcessError < StandardError; end

  # Converts a tnetstring into the encoded data structure.
  #
  # It expects a string argument prefixed with a valid tnetstring and
  # returns a tuple of the parsed object and any remaining string input.
  #
  # === Example
  #
  #  str = '5:12345#'
  #  TNetStrings.parse(str)
  #
  #  #=> [12345, '']
  #
  #  str = '11:hello world,abc123'
  #  TNetStrings.parse(str)
  #
  #  #=> ['hello world', 'abc123']
  #
  INT = '#'
  FLOAT = '^'
  STRING = ','
  ARY = ']'
  HASH = '}'
  NIL = '~'
  BOOL = '!'

  def self.parse(tnetstring)
    payload, payload_type, remain = parse_payload(tnetstring)
    value = case payload_type
    when INT
      Integer(payload)
    when FLOAT
      Float(payload)
    when STRING
      payload
    when ARY
      parse_list(payload)
    when HASH
      parse_dictionary(payload)
    when NIL
      unless payload.bytesize == 0
        raise ProcessError, "Payload must be 0 length for null"
      end
      nil
    when BOOL
      parse_boolean(payload)
    else
      raise ProcessError, "Invalid payload type: #{payload_type}"
    end
    [value, remain]
  end

  COLON = ':'

  def self.parse_payload(data) # :nodoc:
    unless data
      raise ProcessError, "Invalid data to parse; it's empty"
    end
    length, extra = data.split(COLON, 2)
    length = Integer(length)
    if length < 0
      raise ProcessError, "Data length cannot be negative"
    end
    payload = extra.byteslice(0...length)
    unless payload.bytesize == length
      raise ProcessError, "Data is wrong length: #{length} expected but was #{payload.bytesize}"
    end
    extra = extra.byteslice(length..-1)
    unless extra
      raise ProcessError, "No payload type: #{payload}, #{extra}"
    end
    [payload, extra[0, 1], extra[1..-1]]
  end

  def self.parse_list(data) # :nodoc:
    return [] if data.bytesize == 0
    list = []
    value, remain = parse(data)
    list << value

    while remain.bytesize > 0
      value, remain = parse(remain)
      list << value
    end
    list
  end

  def self.parse_dictionary(data) # :nodoc:
    return {} if data.bytesize == 0

    key, value, extra = parse_pair(data)
    result = {key => value}

    while extra.bytesize > 0
        key, value, extra = parse_pair(extra)
        result[key] = value
    end
    result
  end

  def self.parse_pair(data) # :nodoc:
    key, extra = parse(data)
    unless key.kind_of?(String) || key.kind_of?(Symbol)
      raise ProcessError, "Dictionary keys must be Strings or Symbols"
    end
    unless extra
      raise ProcessError, "Unbalanced dictionary store"
    end
    value, extra = parse(extra)

    [key, value, extra]
  end

  FALSE = 'false'
  TRUE = 'true'

  def self.parse_boolean(data) # :nodoc:
    case data
    when FALSE
      false
    when TRUE
      true
    else
      raise ProcessError, "Boolean wasn't 'true' or 'false'"
    end
  end

  # Constructs a tnetstring out of the given object. Valid Ruby object types
  # include strings, integers, boolean values, nil, arrays, and hashes. Arrays
  # and hashes may contain any of the previous valid Ruby object types, but
  # hash keys must be strings.
  #
  # === Example
  #
  #  int = 12345
  #  TNetstring.dump(int)
  #
  #  #=> '5:12345#'
  #
  #  hash = {'hello' => 'world'}
  #  TNetstring.dump(hash)
  #
  #  #=> '16:5:hello,5:world,}'
  #
  TRUE_DUMP = '4:true!'
  FALSE_DUMP = '5:false!'
  NIL_DUMP = '0:~'

  def self.dump(obj)
    case obj
    when Integer
      obj = String(obj)
      "#{obj.bytesize}:#{obj}#"
    when Float
      obj = String(obj)
      "#{obj.bytesize}:#{obj}^"
    when String
      "#{obj.bytesize}:#{obj},"
    when Symbol
      obj = String(obj)
      "#{obj.bytesize}:#{obj},"
    when TrueClass
      TRUE_DUMP
    when FalseClass
      FALSE_DUMP
    when NilClass
      NIL_DUMP
    when Array
      dump_list(obj)
    when Hash
      dump_dictionary(obj)
    else
      raise ProcessError, "Object must be of a primitive type: #{obj.inspect}"
    end
  end

  def self.dump_list(list) # :nodoc:
    contents = list.map {|item| dump(item)}.join
    "#{contents.bytesize}:#{contents}]"
  end

  def self.dump_dictionary(dict) # :nodoc:
    contents = dict.map do |key, value|
      unless key.kind_of?(String) || key.kind_of?(Symbol)
        raise ProcessError, "Dictionary keys must be Strings or Symbols"
      end
      "#{dump(key)}#{dump(value)}"
    end.join
    "#{contents.bytesize}:#{contents}}"
  end
end
