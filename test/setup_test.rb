require "test_helper"

ActiveRecord::Base.establish_connection(
  adapter: "runivedo",
  server: TEST_URL,
  bucket: "01a9e003-0783-475a-b698-485a5450a9d4",
  app: "6e5a3a08-9bb0-4d92-ad04-7c6fed3874fa",
)

class Table < ActiveRecord::Base; end

class SetupTest < MiniTest::Test
  def test_count
    assert Table.count > 10
  end

  def test_queries
    assert_equal "tables", Table.where(id: 1).first.name
  end
end
