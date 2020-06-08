require 'spec_helper'

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
      subject { described_class.dump_using_environment('APPEND' => append) }

      context 'env var is true' do
        let(:append) { 'true' }

        it "should specify append as true" do
          expect(SeedDump).to receive(:dump).with(anything, include(append: true))
          subject
        end
      end

      context 'env var is false' do
        let(:append) { 'false' }

        before do
          FactoryGirl.create(:another_sample)
        end

        it "should specify append as false the first time if the APPEND env var is not 'true' (and true after that)" do
          expect(SeedDump).to receive(:dump).with(anything, include(append: false)).ordered
          expect(SeedDump).to receive(:dump).with(anything, include(append: true)).ordered
          subject
        end
      end
    end

    describe 'BATCH_SIZE' do
      let(:batch_size) { 17 }

      subject { described_class.dump_using_environment('BATCH_SIZE' => batch_size) }

      it 'should pass along the specified batch size' do
        expect(SeedDump).to receive(:dump).with(anything, include(batch_size: batch_size))
        subject
      end

      context 'not specified' do
        it 'should pass along a nil batch size ' do
          expect(SeedDump).to receive(:dump).with(anything, include(batch_size: nil))

          SeedDump.dump_using_environment
        end
      end
    end

    describe 'EXCLUDE' do
      it 'should pass along any attributes to be excluded' do
        expect(SeedDump).to receive(:dump).with(anything, include(exclude: [:baggins, :saggins]))

        SeedDump.dump_using_environment('EXCLUDE' => 'baggins,saggins')
      end
    end

    describe 'FILE' do
      it 'should pass the FILE parameter to the dump method correctly' do
        expect(SeedDump).to receive(:dump).with(anything, include(file: 'blargle'))

        SeedDump.dump_using_environment('FILE' => 'blargle')
      end

      it 'should pass db/seeds.rb as the file parameter if no FILE is specified' do
        expect(SeedDump).to receive(:dump).with(anything, include(file: 'db/seeds.rb'))

        SeedDump.dump_using_environment
      end
    end

    describe 'LIMIT' do
      it 'should apply the specified limit to the records' do
        relation_double = double('ActiveRecord relation double')
        expect(Sample).to receive(:limit).with(5).and_return(relation_double)
        expect(SeedDump).to receive(:dump).with(relation_double, anything)
        SeedDump.stub(:dump)

        SeedDump.dump_using_environment('LIMIT' => '5')
      end
    end

    describe 'MODEL' do
      it 'if MODEL is not specified it should dump all non-empty models' do
        FactoryGirl.create(:another_sample)

        [Sample, AnotherSample].each do |model|
          expect(SeedDump).to receive(:dump).with(model, anything)
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
