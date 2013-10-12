require 'seed_dump'
require 'active_support/core_ext/string'
require 'active_support/descendants_tracker'
require 'active_record'
require 'byebug'
require './spec/helpers'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.order = 'random'

  config.include Helpers
end
