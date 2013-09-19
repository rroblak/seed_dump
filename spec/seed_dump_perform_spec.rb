require 'spec_helper'

describe SeedDump::Perform do
  before(:all) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table 'child_samples', :force => true do |t|
        t.string   'name'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end

      create_table 'samples', :force => true do |t|
        t.string   'string'
        t.text     'text'
        t.integer  'integer'
        t.float    'float'
        t.decimal  'decimal'
        t.datetime 'datetime'
        t.datetime 'timestamp'
        t.time     'time'
        t.date     'date'
        t.binary   'binary'
        t.boolean  'boolean'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end
    end
  end

  before(:each) do
    @sd = SeedDump::Perform.new

    @env = {'MODEL_DIR' => 'spec/models/*.rb',
            'FILE' => Dir.pwd + '/spec/db/seeds.rb',
            'VERBOSE' => false,
            'DEBUG' => false}
  end

  it 'should load models from the specified directory' do
    @sd.setup(@env)

    @sd.load_models

    @sd.models.should eq(["AbstractSample", "ChildSample", "Sample"])
  end

  it 'should support nested models' do
    @env['MODEL_DIR'] = 'spec/models/**/*.rb'

    @sd.setup @env

    @sd.load_models

    @sd.models.should eq(['AbstractSample', 'ChildSample', 'Nested::Sample', 'Sample'])
  end

  context 'when a model has records' do
    before do
      ChildSample.create!(name: Faker::Name.name)

      Sample.create!(string: Faker::Lorem.word,
                     text: Faker::Lorem.paragraphs.join('\n'),
                     integer: rand(1000),
                     float: rand,
                     decimal: rand,
                     datetime: Time.now,
                     timestamp: Time.now.to_i,
                     time: Time.now.strftime('%H:%M:%S'),
                     date: Time.now,
                     binary: nil,
                     boolean: true)
    end

    it 'should not include timestamps if the TIMESTAMPS parameter is false' do
      @env['TIMESTAMPS'] = false

      @sd.setup @env

      @sd.load_models

      @sd.dump_models

      @sd.last_record.should_not include('created_at')
    end

    it 'should include timestamps if the TIMESTAMPS parameter is true' do
      @env['TIMESTAMPS'] = true

      @sd.setup @env

      @sd.load_models

      @sd.dump_models

      @sd.last_record.should include('created_at')
    end

    it 'should include ids if the WITH_ID parameter is true' do
      @env['WITH_ID'] = true

      @sd.setup @env

      @sd.load_models

      @sd.dump_models

      @sd.last_record.should include('id')
    end

    it 'should skip abstract models' do
      @env['MODELS'] = 'AbstractSample'

      @sd.setup @env

      @sd.load_models

      @sd.dump_models

      @sd.last_record.should eq([])
    end

    it 'should use the create method specified in the CREATE_METHOD parameter' do
      @env['CREATE_METHOD'] = 'create!'

      @sd.setup @env

      @sd.load_models

      @sd.dump_models

      @sd.instance_variable_get(:@seed_rb).should include('create!')
    end
  end

  context 'when a model has no records' do
    it 'does not export a create method' do
      @sd.setup @env
      @sd.load_models
      @sd.dump_models

      @sd.last_record.size.should eq(0)
    end
  end
end
