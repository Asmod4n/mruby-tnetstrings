mruby-tnetstrings
===================


Installation
============

First get a working copy of [mruby](https://github.com/mruby/mruby) then add

```ruby
  conf.gem mgem: 'mruby-tnetstrings'
```

to your build_conf.rb

Examples
-------

Objects can be packed with `Object#to_tnetstring` or `TNetStrings.dump`:

```ruby
packed_hash = { 'a': 'hash', 'with': [1, 'embedded', 'array'] }.to_tnetstring
packed_string = TNetStrings.dump('bye')

packed_hash   # => "45:1:a,4:hash,4:with,23:1:1#8:embedded,5:array,]}"
packed_string # => "3:bye,"
```

They are unpacked with `TNetStrings.parse`:

```ruby
TNetStrings.parse(packed_hash)   # => [{"a"=>"hash", "with"=>[1, "embedded", "array"]}, ""]
TNetStrings.parse(packed_string) # => ["bye", ""]
```

A string with multiple packed values can be unpacked by checking if there is a non empty remainder
`TNetStrings.parse`:

```ruby
packed = packed_string + packed_hash

unpacked_string, extra = TNetStrings.parse(packed) # => ["bye", "45:1:a,4:hash,4:with,23:1:1#8:embedded,5:array,]}"]
if extra.bytesize != 0
  unpacked_hash, _ = TNetStrings.parse(extra) # => [{"a"=>"hash", "with"=>[1, "embedded", "array"]}, ""]
end
```
Overriding `to_tnetstring`
---------------------

It's not supported to override `to_tnetstring`, `TNetStrings.dump` ignores it, same when that object is included in a Hash or Array.
This gem treats objects like ruby does, if you want to change the way your custom Class gets handled you can add `to_hash`, `to_ary`, `to_int` or `to_str` methods so it will be packed like a Hash, Array, Integer or String (in that order) then.