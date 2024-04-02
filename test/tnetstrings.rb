assert("NilClass#to_tnetstring") do
  assert_equal([nil, ""], TNetStrings.parse(nil.to_tnetstring))
  assert_equal([nil, ""], TNetStrings.parse(TNetStrings.dump(nil)))
end

assert("FalseClass#to_tnetstring") do
  assert_equal([false, ""], TNetStrings.parse(false.to_tnetstring))
  assert_equal([false, ""], TNetStrings.parse(TNetStrings.dump(false)))
end

assert("TrueClass#to_tnetstring") do
  assert_equal([true, ""], TNetStrings.parse(true.to_tnetstring))
  assert_equal([true, ""], TNetStrings.parse(TNetStrings.dump(true)))
end

assert("Integer#to_tnetstring") do
  [-1, 0, 1].each do |int|
    assert_equal([int, ""], TNetStrings.parse(int.to_tnetstring))
    assert_equal([int, ""], TNetStrings.parse(TNetStrings.dump(int)))
  end
end

if Object.const_defined? "Float"
  assert("Float#to_tnetstring") do
    [-1.0, 0.0, 1.0].each do |float|
      assert_equal([float, ""], TNetStrings.parse(float.to_tnetstring))
      assert_equal([float, ""], TNetStrings.parse(TNetStrings.dump(float)))
    end
  end
end

assert("String#to_tnetstring") do
  assert_equal(['string', ""], TNetStrings.parse('string'.to_tnetstring))
  assert_equal(['string', ""], TNetStrings.parse(TNetStrings.dump('string')))
  assert_equal(["😎", ""], TNetStrings.parse("😎".to_tnetstring))
end

assert("Symbol#to_tnetstring") do
  assert_equal(['symbol', ""], TNetStrings.parse(:symbol.to_tnetstring))
  assert_equal(['symbol', ""], TNetStrings.parse(TNetStrings.dump(:symbol)))
end

assert("Array#to_tnetstring") do
  array = [nil, false, true, 1, -1, "string", [], {}]
  if Object.const_defined? "Float"
    array << 1.1
  end
  assert_equal([array, ""], TNetStrings.parse(array.to_tnetstring))
  assert_equal([array, ""], TNetStrings.parse(TNetStrings.dump(array)))
end

assert("Hash#to_tnetstring") do
  hash = { nil => nil, false => false, true => true, 1 => 1, "string" => "string", [] => [], {} => {} }
  if Object.const_defined? "Float"
    hash[1.1] = 1.1
  end
  assert_equal([hash, ""], TNetStrings.parse(hash.to_tnetstring))
  assert_equal([hash, ""], TNetStrings.parse(TNetStrings.dump(hash)))
end
