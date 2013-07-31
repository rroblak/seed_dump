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
     "DEBUG" => false,
     "RAILS4" => ENV['RAILS4']
    }
  end

  test "load sample model" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @sd.setup @env
    @sd.load_models
    assert_equal ["AbstractSample", "ChildSample", "Sample"], @sd.models
  end

  test "support nested models" do
    @env['MODEL_DIR'] = 'test/models/**/*.rb'
    @sd.setup @env
    @sd.load_models
    assert_equal ["AbstractSample", "ChildSample", "Nested::Sample", "Sample"], @sd.models
  end

  test "without timestamps" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['TIMESTAMPS'] = false
    @sd.setup @env
    @sd.load_models
    @sd.dump_models
    assert !@sd.last_record.include?("created_at"), "Should not include created_at if timestamps are off"
  end

  test "with timestamps" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['TIMESTAMPS'] = true
    @sd.setup @env
    @sd.load_models
    @sd.dump_models
    assert @sd.last_record.include?("created_at"), "Must include created_at if timestamps are desired"
  end

  test "with id" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['WITH_ID'] = true
    @sd.setup @env
    @sd.load_models
    @sd.dump_models
    assert @sd.last_record.include?("id"), "WITH_ID must include id"
  end

  test "skip abstract model" do
    @env['MODELS'] = "AbstractSample"
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['TIMESTAMPS'] = false
    @sd.setup @env
    @sd.load_models
    @sd.dump_models
    assert_equal [], @sd.last_record
  end

  test "create method" do
    @env['MODEL_DIR'] = 'test/models/*.rb'
    @env['CREATE_METHOD'] = 'create!'
    @sd.setup @env
    @sd.load_models
    @sd.dump_models
    assert @sd.instance_variable_get(:@seed_rb) =~ /create!/, 'CREATE_METHOD must specify the creation method'
  end
end
