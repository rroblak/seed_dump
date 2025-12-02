# Mock Rails.application.eager_load! and define some
# Rails models for use in specs.
class Rails
  def self.application
    self
  end

  def self.eager_load!
    @already_called ||= false

    # Define models only if they aren't already defined
    # This prevents errors if eager_load! is called multiple times
    unless @already_called
      Object.const_set('Sample', Class.new(ActiveRecord::Base)) unless defined?(Sample)
      Object.const_set('AnotherSample', Class.new(ActiveRecord::Base)) unless defined?(AnotherSample)
      Object.const_set('YetAnotherSample', Class.new(ActiveRecord::Base)) unless defined?(YetAnotherSample)
      Object.const_set('NoTableModel', Class.new(ActiveRecord::Base)) unless defined?(NoTableModel)
      Object.const_set('EmptyModel', Class.new(ActiveRecord::Base)) unless defined?(EmptyModel)
      Object.const_set('CampaignsManager', Class.new(ActiveRecord::Base)) unless defined?(CampaignsManager)
      Object.const_set('Boss', Class.new(ActiveRecord::Base)) unless defined?(Boss)

      # Model with serialized Hash field (issue #105) - JSON serialization
      unless defined?(SerializedSample)
        serialized_class = Class.new(ActiveRecord::Base) do
          self.table_name = 'serialized_samples'
          serialize :metadata, coder: JSON
        end
        Object.const_set('SerializedSample', serialized_class)
      end

      # Model with default_scope selecting specific columns (issue #165)
      unless defined?(ScopedSelectSample)
        scoped_class = Class.new(ActiveRecord::Base) do
          self.table_name = 'scoped_select_samples'
          default_scope { select(:id, :name) }
        end
        Object.const_set('ScopedSelectSample', scoped_class)
      end

      # Model with created_on/updated_on columns (issue #128)
      unless defined?(TimestampOnSample)
        timestamp_on_class = Class.new(ActiveRecord::Base) do
          self.table_name = 'timestamp_on_samples'
        end
        Object.const_set('TimestampOnSample', timestamp_on_class)
      end

      @already_called = true
    end
  end

  def self.env
    'test'
  end
end

module Helpers
  # Define create_db as a module method (self.create_db)
  def self.create_db
    # Ensure ActiveRecord connection is established before migrations
    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    end

    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define(:version => 1) do
      # Use drop_table with if_exists for idempotency
      drop_table :samples, if_exists: true
      create_table 'samples', :force => true do |t|
        t.string   'string'
        t.text     'text'
        t.integer  'integer'
        t.float    'float'
        t.decimal  'decimal'
        t.datetime 'datetime'
        t.time     'time'
        t.date     'date'
        t.binary   'binary'
        t.boolean  'boolean'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end

      drop_table :another_samples, if_exists: true
      create_table 'another_samples', :force => true do |t|
        t.string   'string'
        t.text     'text'
        t.integer  'integer'
        t.float    'float'
        t.decimal  'decimal'
        t.datetime 'datetime'
        t.time     'time'
        t.date     'date'
        t.binary   'binary'
        t.boolean  'boolean'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end

      drop_table :yet_another_samples, if_exists: true
      create_table 'yet_another_samples', :force => true do |t|
        t.string   'string'
        t.text     'text'
        t.integer  'integer'
        t.float    'float'
        t.decimal  'decimal'
        t.datetime 'datetime'
        t.time     'time'
        t.date     'date'
        t.binary   'binary'
        t.boolean  'boolean'
        t.datetime 'created_at', :null => false
        t.datetime 'updated_at', :null => false
      end

      drop_table :empty_models, if_exists: true
      create_table 'empty_models', force: true

      # Join table without primary key (for issue #167 - HABTM tables)
      drop_table :campaigns_managers, if_exists: true
      create_table 'campaigns_managers', id: false, force: true do |t|
        t.integer :campaign_id
        t.integer :manager_id
      end

      # Table for testing default_scope with select (issue #165)
      drop_table :scoped_select_samples, if_exists: true
      create_table 'scoped_select_samples', force: true do |t|
        t.string :name
        t.string :description
        t.datetime 'created_at', null: false
        t.datetime 'updated_at', null: false
      end

      # Table for testing serialized Hash fields (issue #105) - JSON
      drop_table :serialized_samples, if_exists: true
      create_table 'serialized_samples', force: true do |t|
        t.string :name
        t.text :metadata
        t.datetime 'created_at', null: false
        t.datetime 'updated_at', null: false
      end

      # Table for testing created_on/updated_on exclusion (issue #128)
      drop_table :timestamp_on_samples, if_exists: true
      create_table 'timestamp_on_samples', force: true do |t|
        t.string :name
        t.datetime 'created_on', null: false
        t.datetime 'updated_on', null: false
      end

      # Table for testing model names ending in 's' (issue #121)
      drop_table :bosses, if_exists: true
      create_table 'bosses', force: true do |t|
        t.string :name
        t.datetime 'created_at', null: false
        t.datetime 'updated_at', null: false
      end

    end
  end

  # Keep load_sample_data as an instance method if needed by examples
  def load_sample_data
    Rails.application.eager_load!

    Sample.create!
  end
end
