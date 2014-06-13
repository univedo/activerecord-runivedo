Thread.abort_on_exception = true

require "minitest/autorun"
require "minitest/emoji"
require "active_record"
require "activerecord-runivedo"

TEST_URL = "ws://localhost:9001/f8018f09-fb75-4d3d-8e11-44b2dc796130"
TEST_AUTH = {username: "marvin"}
