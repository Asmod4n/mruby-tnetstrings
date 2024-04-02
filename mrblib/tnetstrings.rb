# Copyright (c) 2011,2015 Matt Yoho, Hendrik Beskow

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
  STRING = ','.freeze
  INT = '#'.freeze
  FLOAT = '^'.freeze
  BOOL = '!'.freeze
  NIL = '~'.freeze
  HASH = '}'.freeze
  ARY = ']'.freeze

  TRUE = 'true'.freeze

  # public functions

  def self.parse(tnetstring)
    payload, payload_type, remain = parse_payload(tnetstring)
    value = case payload_type
    when STRING
      payload
    when INT
      Integer(payload)
    when FLOAT
      Float(payload)
    when BOOL
      payload == TRUE
    when NIL
      nil
    when HASH
      parse_dictionary(payload)
    when ARY
      parse_list(payload)
    else
      raise ProcessError, "Invalid payload type: %s" % payload_type
    end
    [value, remain]
  end

  # Constructs a tnetstring out of the given object. Valid Ruby object types
  # include strings, integers, boolean values, nil, arrays, and hashes. Arrays
  # and hashes may contain any of the previous valid Ruby object types.
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
  TRUE_DUMP = '4:true!'.freeze
  FALSE_DUMP = '5:false!'.freeze
  NIL_DUMP = '0:~'.freeze

  def self.dump(obj)
    case obj
    when Symbol
      obj = String(obj)
      "%d:%s," % [obj.bytesize, obj]
    when String
      "%d:%s," % [obj.bytesize, obj]
    when Integer
      obj = String(obj)
      "%d:%s#" % [obj.bytesize, obj]
    when Float
      obj = String(obj)
      "%d:%s^" % [obj.bytesize, obj]
    when TrueClass
      TRUE_DUMP
    when FalseClass
      FALSE_DUMP
    when NilClass
      NIL_DUMP
    when Hash
      dump_dictionary(obj)
    when Array
      dump_list(obj)
    else
      raise ProcessError, "Object must be of a primitive type: %s" % obj.inspect
    end
  end

  def self.dump_dictionary(dict) # :nodoc:
    contents = dict.map do |key, value|
      "%s%s" % [dump(key), dump(value)]
    end.join
    "%d:%s}" % [contents.bytesize, contents]
  end

  def self.dump_list(list) # :nodoc:
    contents = list.map {|item| dump(item)}.join
    "%d:%s]" % [contents.bytesize, contents]
  end

  private
  # internal functions

  COLON = ':'.freeze

  def self.parse_payload(data) # :nodoc:
    unless data
      raise ProcessError, "Invalid data to parse; it's empty"
    end
    length, extra = data.split(COLON, 2)

    length = Integer(length)
    if length < 0
      raise ProcessError, "Data length cannot be negative"
    end

    payload, extra = extra.byteslice(0, length), extra.byteslice(length..-1)
    unless payload.bytesize == length
      raise ProcessError, "Data is wrong length: %d expected but was %d" % [length, payload.bytesize]
    end
    unless extra
      raise ProcessError, "No payload type: %s, %s" % [payload, extra]
    end

    payload_type, remain = extra.byteslice(0,1), extra.byteslice(1..-1)

    [payload, payload_type, remain]
  end

  def self.parse_pair(data) # :nodoc:
    key, extra = parse(data)
    unless extra
      raise ProcessError, "Unbalanced dictionary store"
    end
    value, extra = parse(extra)

    [key, value, extra]
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
end

class Object
  def to_tnetstring
    if self.respond_to? :to_hash
      TNetStrings.dump_dictionary(self.to_hash)
    elsif self.respond_to? :to_ary
      TNetStrings.dump_list(self.to_ary)
    elsif self.respond_to? :to_int
      obj = String(self.to_int)
      "%d:%s#" % [obj.bytesize, obj]
    elsif self.respond_to? :to_str
      obj = self.to_str
      "%d:%s," % [obj.bytesize, obj]
    else
      obj = String(self)
      "%d:%s," % [obj.bytesize, obj]
    end
  end
end

class Symbol
  def to_tnetstring
    obj = String(self)
    "%d:%s," % [obj.bytesize, obj]
  end
end

class String
  def to_tnetstring
    "%d:%s," % [self.bytesize, self]
  end
end

class Integer
  def to_tnetstring
    obj = String(self)
    "%d:%s#" % [obj.bytesize, obj]
  end
end

class Float
  def to_tnetstring
    obj = String(self)
    "%d:%s^" % [obj.bytesize, obj]
  end
end

class TrueClass
  def to_tnetstring
    TNetStrings::TRUE_DUMP
  end
end

class FalseClass
  def to_tnetstring
    TNetStrings::FALSE_DUMP
  end
end

class NilClass
  def to_tnetstring
    TNetStrings::NIL_DUMP
  end
end

class Hash
  def to_tnetstring
    TNetStrings.dump_dictionary(self)
  end
end

class Array
  def to_tnetstring
    TNetStrings.dump_list(self)
  end
end
