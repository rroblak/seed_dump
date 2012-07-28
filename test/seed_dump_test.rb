require 'test_helper'
require "seed_dump/perform"

class SeedDumpTest < ActiveSupport::TestCase

  setup do
    @sd = SeedDump::Perform.new
    # universial options for every test
    @env = {
     "MODEL_DIR" => Dir.pwd + '/test/models/*.rb',
     "FILE" => Dir.pwd + '/test/db/seeds.rb',
     "DEBUG" => true
    }
  end

  test "load sample model" do
    @sd.setup @env 
    @sd.loadModels
    assert_equal ["Sample"], @sd.models
  end

  test "skip callbacks" do
    @sd.setup @env 
    @sd.loadModels
    assert_equal ["Sample"], @sd.models
  end
end
