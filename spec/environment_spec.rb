require 'spec_helper'

describe SeedDump do
  describe '.dump_using_environment' do
    # Schema creation and model loading are handled in spec_helper's before(:suite).

    before(:each) do
      # Clean DB and create a fresh sample before each example
      DatabaseCleaner.start
      FactoryBot.create(:sample)
    end

    after(:each) do
      # Clean DB after each example
       DatabaseCleaner.clean
    end


    describe 'APPEND' do
      it "should specify append as true if the APPEND env var is 'true'" do
        expect(SeedDump).to receive(:dump).with(anything, include(append: true))
        # Need to stub dump for other models if they exist in this context
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment('APPEND' => 'true')
      end

      it "should specify append as true if the APPEND env var is 'TRUE'" do
        expect(SeedDump).to receive(:dump).with(anything, include(append: true))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment('APPEND' => 'TRUE')
      end

      it "should specify append as false the first time if the APPEND env var is not 'true' (and true after that)" do
        FactoryBot.create(:another_sample)
        expect(SeedDump).to receive(:dump).with(Sample, include(append: false)).ordered
        expect(SeedDump).to receive(:dump).with(AnotherSample, include(append: true)).ordered
        # Explicitly set MODELS to control order and prevent other models interfering
        SeedDump.dump_using_environment('APPEND' => 'false', 'MODELS' => 'Sample,AnotherSample')
      end
    end

    describe 'BATCH_SIZE' do
      it 'should pass along the specified batch size' do
        expect(SeedDump).to receive(:dump).with(anything, include(batch_size: 17))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment('BATCH_SIZE' => '17')
      end

      it 'should pass along a nil batch size if BATCH_SIZE is not specified' do
        expect(SeedDump).to receive(:dump).with(anything, include(batch_size: nil))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment
      end
    end

    describe 'EXCLUDE' do
      it 'should pass along any attributes to be excluded' do
        expect(SeedDump).to receive(:dump).with(anything, include(exclude: [:baggins, :saggins]))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment('EXCLUDE' => 'baggins,saggins')
      end
    end

    describe 'FILE' do
      it 'should pass the FILE parameter to the dump method correctly' do
        expect(SeedDump).to receive(:dump).with(anything, include(file: 'blargle'))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment('FILE' => 'blargle')
      end

      it 'should pass db/seeds.rb as the file parameter if no FILE is specified' do
        expect(SeedDump).to receive(:dump).with(anything, include(file: 'db/seeds.rb'))
        allow(SeedDump).to receive(:dump).with(AnotherSample, anything) if defined?(AnotherSample)
        allow(SeedDump).to receive(:dump).with(YetAnotherSample, anything) if defined?(YetAnotherSample)
        SeedDump.dump_using_environment
      end
    end

    describe 'LIMIT' do
      it 'should apply the specified limit to the records' do
        relation_double = double('ActiveRecord relation double')
        allow(Sample).to receive(:limit).with(5).and_return(relation_double)
        expect(SeedDump).to receive(:dump).with(relation_double, anything)
        # Allow other calls if necessary
        allow(SeedDump).to receive(:dump).with(instance_of(Class), anything) unless relation_double.is_a?(Class)


        SeedDump.dump_using_environment('LIMIT' => '5')
      end
    end

    ['', 'S'].each do |model_suffix|
      model_env = 'MODEL' + model_suffix

      describe model_env do
        context "if #{model_env} is not specified" do
          it "should dump all non-empty models" do
            FactoryBot.create(:another_sample)
            expect(SeedDump).to receive(:dump).with(Sample, anything)
            expect(SeedDump).to receive(:dump).with(AnotherSample, anything)
            SeedDump.dump_using_environment
          end
        end

        context "if #{model_env} is specified" do
          it "should dump only the specified model" do
            FactoryBot.create(:another_sample)
            expect(SeedDump).to receive(:dump).with(Sample, anything)
            # Ensure the other model is NOT dumped
            expect(SeedDump).not_to receive(:dump).with(AnotherSample, anything)
            SeedDump.dump_using_environment(model_env => 'Sample')
          end

          it "should not dump empty models" do
            expect(SeedDump).not_to receive(:dump).with(EmptyModel, anything)
            # Ensure Sample is still dumped
            expect(SeedDump).to receive(:dump).with(Sample, anything)
            SeedDump.dump_using_environment(model_env => 'EmptyModel, Sample')
          end
        end
      end
    end

    describe "MODELS_EXCLUDE" do
      it "should dump all non-empty models except the specified models" do
        FactoryBot.create(:another_sample)
        expect(SeedDump).to receive(:dump).with(Sample, anything)
        # Ensure the excluded model is NOT dumped
        expect(SeedDump).not_to receive(:dump).with(AnotherSample, anything)
        SeedDump.dump_using_environment('MODELS_EXCLUDE' => 'AnotherSample')
      end
    end

    it 'should run ok without ActiveRecord::SchemaMigration being set (needed for Rails Engines)' do
      # Ensure Sample model exists before trying to remove SchemaMigration
      expect(defined?(Sample)).to be_truthy
      schema_migration_defined = defined?(ActiveRecord::SchemaMigration)
      schema_migration = ActiveRecord::SchemaMigration if schema_migration_defined

      # Stub the dump method before removing the constant
      allow(SeedDump).to receive(:dump)

      # Use remove_const carefully only if it's defined
      ActiveRecord.send(:remove_const, :SchemaMigration) if schema_migration_defined

      begin
        expect { SeedDump.dump_using_environment }.not_to raise_error
      ensure
        # Ensure the constant is restored only if it was originally defined
        ActiveRecord.const_set(:SchemaMigration, schema_migration) if schema_migration_defined && !defined?(ActiveRecord::SchemaMigration)
      end
    end
  end
end
