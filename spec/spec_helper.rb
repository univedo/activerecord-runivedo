require 'rspec'
require 'active_record'
require 'active_record-runivedo'
require 'timeout'

RSpec.configure do |c|
  c.around(:each) do |example|
    Timeout::timeout(1) {example.run}
  end
end
