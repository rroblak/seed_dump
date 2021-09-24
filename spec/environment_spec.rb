require 'spec_helper'

describe SeedDump do
  describe '.dump_using_environment' do
    before(:all) do
      create_db
    end

    before do
      Rails.application.eager_load!

      FactoryBot.create(:sample)
    end

    describe 'INSERT_ALL' do
      it "specifies insert_all as true if the INSERT_ALL env var is 'true'" do
        described_class.should_receive(:dump).with(anything, include(insert_all: true))

        described_class.dump_using_environment('INSERT_ALL' => 'true')
      end
    end

    describe 'DUMP_ALL' do
      it 'sets empty array if dump all is true' do
        described_class.should_receive(:dump).with(anything, include(exclude: []))

        described_class.dump_using_environment('DUMP_ALL' => 'true')
      end
    end

    describe 'APPEND' do
      it "specifies append as true if the APPEND env var is 'true'" do
        described_class.should_receive(:dump).with(anything, include(append: true))

        described_class.dump_using_environment('APPEND' => 'true')
      end

      it "specifies append as true if the APPEND env var is 'TRUE'" do
        described_class.should_receive(:dump).with(anything, include(append: true))

        described_class.dump_using_environment('APPEND' => 'TRUE')
      end

      it "specifies append as false the first time if the APPEND env var is not 'true' (and true after that)" do
        FactoryBot.create(:another_sample)

        described_class.should_receive(:dump).with(anything, include(append: false)).ordered
        described_class.should_receive(:dump).with(anything, include(append: true)).ordered

        described_class.dump_using_environment('APPEND' => 'false')
      end
    end

    describe 'BATCH_SIZE' do
      it 'passes along the specified batch size' do
        described_class.should_receive(:dump).with(anything, include(batch_size: 17))

        described_class.dump_using_environment('BATCH_SIZE' => '17')
      end

      it 'passes along a nil batch size if BATCH_SIZE is not specified' do
        described_class.should_receive(:dump).with(anything, include(batch_size: nil))

        described_class.dump_using_environment
      end
    end

    describe 'EXCLUDE' do
      it 'passes along any attributes to be excluded' do
        described_class.should_receive(:dump).with(anything, include(exclude: %i[baggins saggins]))

        described_class.dump_using_environment('EXCLUDE' => 'baggins,saggins')
      end
    end

    describe 'FILE' do
      it 'passes the FILE parameter to the dump method correctly' do
        described_class.should_receive(:dump).with(anything, include(file: 'blargle'))

        described_class.dump_using_environment('FILE' => 'blargle')
      end

      it 'passes db/seeds.rb as the file parameter if no FILE is specified' do
        described_class.should_receive(:dump).with(anything, include(file: 'db/seeds.rb'))

        described_class.dump_using_environment
      end
    end

    describe 'LIMIT' do
      it 'applies the specified limit to the records' do
        relation_double = double('ActiveRecord relation double')
        Sample.should_receive(:limit).with(5).and_return(relation_double)

        described_class.should_receive(:dump).with(relation_double, anything)
        described_class.stub(:dump)

        described_class.dump_using_environment('LIMIT' => '5')
      end
    end

    ['', 'S'].each do |model_suffix|
      model_env = "MODEL#{model_suffix}"

      describe model_env do
        context "if #{model_env} is not specified" do
          it 'dumps all non-empty models' do
            FactoryBot.create(:another_sample)

            [Sample, AnotherSample].each do |model|
              SeedDump.should_receive(:dump).with(model, anything)
            end

            SeedDump.dump_using_environment
          end
        end

        context "if #{model_env} is specified" do
          it 'dumps only the specified model' do
            FactoryBot.create(:another_sample)

            SeedDump.should_receive(:dump).with(Sample, anything)

            SeedDump.dump_using_environment(model_env => 'Sample')
          end

          it 'does not dump empty models' do
            SeedDump.should_not_receive(:dump).with(EmptyModel, anything)

            SeedDump.dump_using_environment(model_env => 'EmptyModel, Sample')
          end
        end
      end
    end

    describe 'MODELS_EXCLUDE' do
      it 'dumps all non-empty models except the specified models' do
        FactoryBot.create(:another_sample)

        described_class.should_receive(:dump).with(Sample, anything)

        described_class.dump_using_environment('MODELS_EXCLUDE' => 'AnotherSample')
      end
    end

    it 'runs ok without ActiveRecord::SchemaMigration being set (needed for Rails Engines)' do
      schema_migration = ActiveRecord::SchemaMigration

      ActiveRecord.send(:remove_const, :SchemaMigration)

      described_class.stub(:dump)

      begin
        described_class.dump_using_environment
      ensure
        ActiveRecord.const_set(:SchemaMigration, schema_migration)
      end
    end
  end
end
