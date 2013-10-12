require 'spec_helper'

describe SeedDump do
  describe '#dump_models' do
    before(:all) do
      create_db
    end

    before(:each) do
      @sd = SeedDump.new

      @env = {'FILE' => Dir.pwd + '/spec/db/seeds.rb',
              'VERBOSE' => false,
              'DEBUG' => false}

      ActiveSupport::DescendantsTracker.clear
    end

    it 'should not include timestamps if the TIMESTAMPS parameter is false' do
      @env['TIMESTAMPS'] = false

      @sd.setup @env

      @sd.dump_models

      @sd.last_record.should_not include('created_at')
    end

    it 'should include timestamps if the TIMESTAMPS parameter is true' do
      @env['TIMESTAMPS'] = true

      @sd.setup @env

      @sd.dump_models

      @sd.last_record.should include('created_at')
    end

    it 'should include ids if the WITH_ID parameter is true' do
      @env['WITH_ID'] = true

      @sd.setup @env

      @sd.dump_models

      @sd.last_record.should include('id')
    end

    it 'should skip abstract models' do
      @env['MODELS'] = 'AbstractSample'

      @sd.setup @env

      @sd.dump_models

      @sd.last_record.should eq([])
    end

    it 'should respect the MODELS parameter' do
      @env['MODELS'] = 'Sample'

      @sd.setup @env

      @sd.dump_models.should eq("\nSample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")
    end

    it 'should use the create method specified in the CREATE_METHOD parameter' do
      @env['CREATE_METHOD'] = 'create'

      @sd.setup @env

      @sd.dump_models.should eq("\nChildSample.create([\n  { :name => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nNested::Sample.create([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nSample.create([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")
    end

    it "should use 'create!' as the default create method" do
      @sd.setup @env

      @sd.dump_models.should eq("\nChildSample.create!([\n  { :name => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nNested::Sample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nSample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")
    end

    it "should return the contents of the dump" do
      @sd.setup @env

      @sd.dump_models.should eq("\nChildSample.create!([\n  { :name => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nNested::Sample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nSample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")
    end

    it 'should run ok without ActiveRecord::SchemaMigration being set (needed for Rails Engines)' do
      schema_migration = ActiveRecord::SchemaMigration

      ActiveRecord.send(:remove_const, :SchemaMigration)

      begin
        @sd.setup @env

        @sd.dump_models
      ensure
        ActiveRecord.const_set(:SchemaMigration, schema_migration)
      end
    end

    it "should skip any models whose tables don't exist" do
      @sd.setup @env

      @sd.dump_models.should eq("\nChildSample.create!([\n  { :name => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nNested::Sample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n\nSample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")

    it "should skip any models that don't have have any rows" do
      @sd.setup @env

      @sd.dump_models.should_not include('EmptyModel')
    end

    it 'should respect the LIMIT parameter' do
      load_sample_data
      load_sample_data

      @env['MODELS'] = 'Sample'
      @env['LIMIT'] = '1'

      @sd.setup @env

      @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
    end
  end
end
