require 'test_helper'
require "seed_dump/perform"

class SeedDumpTest < ActiveSupport::TestCase

  setup do
    @sd = SeedDump::Perform.new
    # universial options for every test
    @env = {
     "MODEL_DIR" => 'test/models/**.rb',
     "FILE" => Dir.pwd + '/test/db/seeds.rb',
     "VERBOSE" => false,
     "DEBUG" => false 
    }
  end

  test "load sample model" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @sd.setup @env 
    @sd.loadModels
    assert_equal ["Sample"], @sd.models
  end

  test "support nested models" do
    @env['MODEL_DIR'] = 'test/models/**/*.rb'
    @sd.setup @env 
    @sd.loadModels
    assert_equal ["Nested::Sample", "Sample"], @sd.models
  end

  test "without timestamps" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['TIMESTAMPS'] = false
    @sd.setup @env
    @sd.loadModels
    @sd.dumpModels
    assert !@sd.last_record.include?("created_at"), "Should not include created_at if timestamps are off"
  end

  test "with timestamps" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['TIMESTAMPS'] = true
    @sd.setup @env
    @sd.loadModels
    @sd.dumpModels
    assert @sd.last_record.include?("created_at"), "Must include created_at if timestamps are desired"
  end

  test "with id" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['WITH_ID'] = true
    @sd.setup @env
    @sd.loadModels
    @sd.dumpModels
    assert @sd.last_record.include?("id"), "WITH_ID must include id"
  end


end
