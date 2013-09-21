require 'seed_dump'
require 'active_support/core_ext/string'
require 'active_record'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.run_all_when_everything_filtered = true

  config.filter_run :focus

  config.order = 'random'
end
