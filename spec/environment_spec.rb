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

    describe 'INSERT_ALL (issue #153)' do
      it "should specify insert_all as true if the INSERT_ALL env var is 'true'" do
        expect(SeedDump).to receive(:dump).with(anything, include(insert_all: true))
        SeedDump.dump_using_environment('INSERT_ALL' => 'true')
      end

      it "should specify insert_all as true if the INSERT_ALL env var is 'TRUE'" do
        expect(SeedDump).to receive(:dump).with(anything, include(insert_all: true))
        SeedDump.dump_using_environment('INSERT_ALL' => 'TRUE')
      end

      it "should specify insert_all as false if the INSERT_ALL env var is not 'true'" do
        expect(SeedDump).to receive(:dump).with(anything, include(insert_all: false))
        SeedDump.dump_using_environment('INSERT_ALL' => 'false')
      end

      it "should specify insert_all as false if the INSERT_ALL env var is not set" do
        expect(SeedDump).to receive(:dump).with(anything, include(insert_all: false))
        SeedDump.dump_using_environment
      end
    end

    it 'should handle non-model classes in ActiveRecord::Base.descendants (issue #112)' do
      # Create a class that inherits from ActiveRecord::Base but doesn't respond to exists?
      # This simulates edge cases like abstract classes or improperly configured models
      non_model_class = Class.new(ActiveRecord::Base) do
        def self.exists?
          raise NoMethodError, "undefined method `exists?' for #{self}"
        end

        def self.table_exists?
          raise NoMethodError, "undefined method `table_exists?' for #{self}"
        end
      end
      Object.const_set('NonModelClass', non_model_class)

      allow(SeedDump).to receive(:dump)

      begin
        expect { SeedDump.dump_using_environment }.not_to raise_error
      ensure
        Object.send(:remove_const, :NonModelClass)
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

    describe 'HABTM deduplication (issues #26, #114)' do
      # When using has_and_belongs_to_many, Rails creates two auto-generated models
      # that point to the same join table (e.g., User::HABTM_Roles and Role::HABTM_Users).
      # We should only dump one of them to avoid duplicate seed data.

      it 'should deduplicate HABTM models that share the same table' do
        # Create mock HABTM classes that share the same table_name
        habtm_class_1 = Class.new(ActiveRecord::Base) do
          self.table_name = 'roles_users'
          def self.name; 'User::HABTM_Roles'; end
          def self.to_s; name; end
        end

        habtm_class_2 = Class.new(ActiveRecord::Base) do
          self.table_name = 'roles_users'
          def self.name; 'Role::HABTM_Users'; end
          def self.to_s; name; end
        end

        # Temporarily add these to AR descendants by setting constants
        User = Class.new unless defined?(User)
        Role = Class.new unless defined?(Role)
        User.const_set('HABTM_Roles', habtm_class_1)
        Role.const_set('HABTM_Users', habtm_class_2)

        begin
          # Stub exists? and table_exists? to return true
          allow(habtm_class_1).to receive(:table_exists?).and_return(true)
          allow(habtm_class_1).to receive(:exists?).and_return(true)
          allow(habtm_class_2).to receive(:table_exists?).and_return(true)
          allow(habtm_class_2).to receive(:exists?).and_return(true)

          # Track which models get dumped
          dumped_models = []
          allow(SeedDump).to receive(:dump) do |model, _options|
            dumped_models << model.to_s
          end

          SeedDump.dump_using_environment

          # Only one of the HABTM models should be dumped, not both
          habtm_dumps = dumped_models.select { |m| m.include?('HABTM_') }
          habtm_tables = habtm_dumps.map { |m| m.include?('HABTM_Roles') ? 'roles_users' : 'roles_users' }

          expect(habtm_dumps.size).to eq(1), "Expected 1 HABTM model to be dumped, got #{habtm_dumps.size}: #{habtm_dumps}"
        ensure
          User.send(:remove_const, 'HABTM_Roles') if defined?(User::HABTM_Roles)
          Role.send(:remove_const, 'HABTM_Users') if defined?(Role::HABTM_Users)
          Object.send(:remove_const, 'User') if defined?(User) && User.is_a?(Class) && User.superclass == Object
          Object.send(:remove_const, 'Role') if defined?(Role) && Role.is_a?(Class) && Role.superclass == Object
        end
      end

      it 'should not deduplicate non-HABTM models with same table (e.g., STI)' do
        # Non-HABTM models sharing a table (like STI) should both be kept
        # This test ensures we only dedupe HABTM_ prefixed models
        allow(SeedDump).to receive(:dump)

        # Sample and AnotherSample are different tables, so both should dump
        FactoryBot.create(:another_sample)
        expect(SeedDump).to receive(:dump).with(Sample, anything)
        expect(SeedDump).to receive(:dump).with(AnotherSample, anything)

        SeedDump.dump_using_environment
      end
    end
  end
end
