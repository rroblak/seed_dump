# Explicitly require logger before active_support to potentially resolve
# constant lookup issues in newer Ruby versions with older ActiveSupport.
require 'logger'

require 'active_support'
require 'active_record'

require 'tempfile'

require 'byebug'

require 'database_cleaner/active_record' # Use the specific cleaner
require 'factory_bot'

# Require the main gem file to define SeedDump constant
require_relative '../lib/seed_dump'

require_relative './helpers' # Use require_relative for local files

# Load FactoryBot definitions
FactoryBot.find_definitions

RSpec.configure do |config|
  config.order = 'random'

  # Include helper methods for use within examples (it blocks)
  config.include Helpers

  # Configure DatabaseCleaner and Schema Setup
  config.before(:suite) do
    # Ensure mock Rails models are defined once for the suite
    Rails.application.eager_load! if defined?(Rails) && Rails.respond_to?(:application)

    # Create the database schema once before the suite runs
    begin
      Helpers.create_db
    rescue => e
      puts "== RSpec: ERROR creating database schema: #{e.message} =="
      puts e.backtrace
      raise e # Re-raise the error to fail the suite setup
    end


    # Set up DatabaseCleaner strategy and clean once initially
    # Use truncation strategy for initial clean
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  # Use :truncation strategy before and after each example for thorough cleaning
  config.before(:each) do
    DatabaseCleaner.strategy = :truncation # Set strategy before starting
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
