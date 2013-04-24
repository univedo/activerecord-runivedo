require "spec_helper"

ActiveRecord::Base.establish_connection(
  adapter: "runivedo",
  url: "ws://localhost:9001/f8018f09-fb75-4d3d-8e11-44b2dc796130",
  app: "6e5a3a08-9bb0-4d92-ad04-7c6fed3874fa"
)

describe 'Setup' do
  it 'connects to univedo' do
    # class Table < ActiveRecord::Base
    # end

    # p Table.first
    p ActiveRecord::Base::connection.execute("SELECT * FROM tables")
  end
end
