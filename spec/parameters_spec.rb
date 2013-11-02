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

    context 'TIMESTAMPS' do
      it 'should not include timestamps if the TIMESTAMPS parameter is false' do
        Rails.application.eager_load!

        @env['MODELS'] = 'Sample'
        @env['TIMESTAMPS'] = false

        @sd.setup @env

        load_sample_data

        @sd.dump_models.should match(/^\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil }\n\]\)\n\n\n$/)
      end

      it 'should include timestamps if the TIMESTAMPS parameter is true' do
        Rails.application.eager_load!

        @env['MODELS'] = 'Sample'
        @env['TIMESTAMPS'] = true

        load_sample_data

        @sd.setup @env

        @sd.dump_models.should match(/^\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n$/)
      end
    end

    context 'WITH_ID' do
      it 'should include ids if the WITH_ID parameter is true' do
        Rails.application.eager_load!

        @env['MODELS'] = 'Sample'
        @env['WITH_ID'] = true

        @sd.setup @env

        load_sample_data

        @sd.dump_models.should match(/^\nSample\.create!\(\[\n  { :id => \d+, :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n$/)
      end
    end

    context 'MODELS' do
      it 'should respect the MODELS parameter' do
        Rails.application.eager_load!

        @env['MODELS'] = 'Sample'

        @sd.setup @env

        load_sample_data

        @sd.dump_models.should match(/\nSample\.create!\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
      end
    end

    context 'CREATE_METHOD' do
      it 'should use the create method specified in the CREATE_METHOD parameter' do
        load_sample_data

        @env['MODELS'] = 'Sample'
        @env['CREATE_METHOD'] = 'create'

        @sd.setup @env

        @sd.dump_models.should match(/\nSample\.create\(\[\n  { :string => nil, :text => nil, :integer => nil, :float => nil, :decimal => nil, :datetime => nil, :timestamp => nil, :time => nil, :date => nil, :binary => nil, :boolean => nil, :created_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", :updated_at => "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}" }\n\]\)\n\n\n/)
      end
    end

    context 'LIMIT' do
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
end
