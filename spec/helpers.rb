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
    end
  end

  # Keep load_sample_data as an instance method if needed by examples
  def load_sample_data
    Rails.application.eager_load!

    Sample.create!
  end
end
