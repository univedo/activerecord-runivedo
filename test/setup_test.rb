require "test_helper"

ActiveRecord::Base.establish_connection(
  adapter: "runivedo",
  server: TEST_URL,
  bucket: UUIDTools::UUID.random_create.to_s,
  app: "cefb4ed2-4ce3-4825-8550-b68a3c142f0a",
  username: "marvin",
  uts: "Test Perspective.xml",
)

class Dummy < ActiveRecord::Base
  self.table_name = "dummy"

  validates :dummy_uuid, uniqueness: true
end

class SetupTest < MiniTest::Test
  def test_count
    assert Dummy.count >= 0
  end

  def test_queries
    Dummy.create! dummy_char: "foo"
    assert_equal "foo", Dummy.all.last.dummy_char
  end

  def test_queries_uuid
    uuid = UUIDTools::UUID.random_create
    Dummy.create! dummy_uuid: uuid
    assert_equal uuid, Dummy.all.last.dummy_uuid
  end

  def test_update
    d = Dummy.create!
    d.dummy_char = "foobar"
    d.save
    assert_equal "foobar", Dummy.all.last.dummy_char
  end

  def test_binary
    d = Dummy.create! dummy_blob: "\0".b
  end

  def test_string
    s = %Q{foo"bar'baz}
    Dummy.create! dummy_char: s
    assert_equal s, Dummy.all.last.dummy_char
  end
end
