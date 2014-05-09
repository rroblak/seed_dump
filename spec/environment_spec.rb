require 'spec_helper'

shared_examples 'dumps with expected options' do |*args|
  it 'specifies expected options obtained from environment' do
    options = args.extract_options!
    env = Hash[args.each_slice(2).to_a]
    SeedDump.should_receive(:dump).with(anything, include(options))
    SeedDump.dump_using_environment(env)
  end
end

describe SeedDump do
  describe '.dump_using_environment' do
    before(:all) do
      create_db
    end

    before(:each) do
      Rails.application.eager_load!

      FactoryGirl.create(:sample)
    end

    describe 'APPEND' do
      it_behaves_like 'dumps with expected options', 'APPEND', 'true', append: true

      it "should specify append as false the first time if the APPEND env var is not 'true' (and true after that)" do
        FactoryGirl.create(:another_sample)

        SeedDump.should_receive(:dump).with(anything, include(append: false)).ordered
        SeedDump.should_receive(:dump).with(anything, include(append: true)).ordered

        SeedDump.dump_using_environment('APPEND' => 'false')
      end
    end

    describe 'BATCH_SIZE' do
      it_behaves_like 'dumps with expected options', 'BATCH_SIZE', '17', batch_size: 17
      it_behaves_like 'dumps with expected options', batch_size: nil
    end

    describe 'EXCLUDE' do
      it_behaves_like 'dumps with expected options', 'EXCLUDE', 'baggins,saggins', exclude: [:baggins, :saggins]
    end

    describe 'FILE' do
      it_behaves_like 'dumps with expected options', 'FILE', 'blargle', file: 'blargle'
      it_behaves_like 'dumps with expected options', file: 'db/seeds.rb'
    end

    describe 'LIMIT' do
      it 'should apply the specified limit to the records' do
        relation_double = double('ActiveRecord relation double')
        Sample.should_receive(:limit).with(5).and_return(relation_double)

        SeedDump.should_receive(:dump).with(relation_double, anything)
        SeedDump.stub(:dump)

        SeedDump.dump_using_environment('LIMIT' => '5')
      end
    end

    describe 'MODEL' do
      it 'if MODEL is not specified it should dump all non-empty models' do
        FactoryGirl.create(:another_sample)

        [Sample, AnotherSample].each do |model|
          SeedDump.should_receive(:dump).with(model, anything)
        end

        SeedDump.dump_using_environment
      end

      it 'if MODEL is specified it should only dump the specified model' do
        FactoryGirl.create(:another_sample)

        SeedDump.should_receive(:dump).with(Sample, anything)

        SeedDump.dump_using_environment('MODEL' => 'Sample')
      end
    end

    describe 'MODELS' do
      it 'if MODELS is not specified it should dump all non-empty models' do
        FactoryGirl.create(:another_sample)

        [Sample, AnotherSample].each do |model|
          SeedDump.should_receive(:dump).with(model, anything)
        end

        SeedDump.dump_using_environment
      end

      it 'if MODELS is specified it should only dump those models' do
        FactoryGirl.create(:another_sample)
        FactoryGirl.create(:yet_another_sample)

        SeedDump.should_receive(:dump).with(Sample, anything)
        SeedDump.should_receive(:dump).with(AnotherSample, anything)

        SeedDump.dump_using_environment('MODELS' => 'Sample, AnotherSample')
      end
    end

    describe 'USE_IMPORT' do
      it_behaves_like 'dumps with expected options', use_import: false
      it_behaves_like 'dumps with expected options', 'USE_IMPORT', 'true', use_import: true
      it_behaves_like 'dumps with expected options', 'USE_IMPORT', 't', use_import: true
      it_behaves_like 'dumps with expected options', 'USE_IMPORT', '1', use_import: true
      it_behaves_like 'dumps with expected options', 'USE_IMPORT', 'unknown', use_import: false
    end

    describe 'VALIDATE' do
      it_behaves_like 'dumps with expected options', validate: false
      it_behaves_like 'dumps with expected options', 'VALIDATE', 'true', validate: true
      it_behaves_like 'dumps with expected options', 'VALIDATE', 't', validate: true
      it_behaves_like 'dumps with expected options', 'VALIDATE', '1', validate: true
      it_behaves_like 'dumps with expected options', 'VALIDATE', 'unknown', validate: false
    end

    it 'should run ok without ActiveRecord::SchemaMigration being set (needed for Rails Engines)' do
      schema_migration = ActiveRecord::SchemaMigration

      ActiveRecord.send(:remove_const, :SchemaMigration)

      SeedDump.stub(:dump)

      begin
        SeedDump.dump_using_environment
      ensure
        ActiveRecord.const_set(:SchemaMigration, schema_migration)
      end
    end
   end
 end
