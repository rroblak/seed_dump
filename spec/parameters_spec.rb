require 'spec_helper'

describe SeedDump do
  describe '#dump_models parameters' do
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

    context 'MODELS' do
      it 'should respect the MODELS parameter' do
        Rails.application.eager_load!

        @env['MODELS'] = 'Sample'

        @sd.setup @env

        load_sample_data

        @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil }\n\]\)\n\n\n/)
      end
    end

    context 'CREATE_METHOD' do
      it 'should use the create method specified in the CREATE_METHOD parameter' do
        load_sample_data

        @env['MODELS'] = 'Sample'
        @env['CREATE_METHOD'] = 'create'

        @sd.setup @env

        @sd.dump_models.should match(/\nSample\.create\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil }\n\]\)\n\n\n/)
      end
    end

    context 'LIMIT' do
      it 'should respect the LIMIT parameter' do
        load_sample_data
        load_sample_data

        @env['MODELS'] = 'Sample'
        @env['LIMIT'] = '1'

        @sd.setup @env

        @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil }\n\]\)\n\n\n/)
      end
    end

    context 'EXCLUDE' do
      it 'should default to excluding :id, :created_at, and :updated_at' do
        load_sample_data

        @sd.setup @env

        @sd.dump_models.should_not include('id')
        @sd.dump_models.should_not include('created_at')
        @sd.dump_models.should_not include('updated_at')
      end

      it "should not exclude any attributes if it's specified as empty" do
        load_sample_data

        @env['EXCLUDE'] = ''

        @sd.setup @env

        @sd.dump_models.should include('id')
        @sd.dump_models.should include('created_at')
        @sd.dump_models.should include('updated_at')
      end
    end
  end
end
