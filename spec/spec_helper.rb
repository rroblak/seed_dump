require 'seed_dump'
require 'active_support/core_ext/string'
require 'active_support/descendants_tracker'
require 'active_record'
require 'byebug'
require 'database_cleaner'
require './spec/helpers'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.order = 'random'

  config.include Helpers

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
