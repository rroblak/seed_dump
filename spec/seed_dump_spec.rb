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

    it "should use 'create!' as the default create method" do
      load_sample_data

      @env['MODELS'] = 'Sample'

      @sd.setup @env

      @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
    end

    it "should return the contents of the dump" do
      load_sample_data

      @env['MODELS'] = 'Sample'

      @sd.setup @env

      @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
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

      load_sample_data

      @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
    end

    it "should skip any models that don't have have any rows" do
      @sd.setup @env

      @sd.dump_models.should_not include('EmptyModel')
    end

    it 'should only pull attributes that are returned as strings' do
      load_sample_data

      @env['MODELS'] = 'Sample'
      @env['LIMIT'] = '1'

      @sd.setup @env

      original_attributes = Sample.new.attributes
      attributes = original_attributes.merge(['col1', 'col2', 'col3'] => 'ABC')

      Sample.any_instance.stub(:attributes).and_return(attributes)

      @sd.dump_models.should eq("\nSample.create!([\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => nil, :updated_at => nil }\n])\n\n\n")
    end
  end
end
