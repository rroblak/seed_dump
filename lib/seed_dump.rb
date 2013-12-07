require 'seed_dump/console_methods/enumeration'
require 'seed_dump/console_methods'
require 'seed_dump/environment'

class SeedDump
  extend Environment
  extend  ConsoleMethods

  require 'seed_dump/railtie' if defined?(Rails)
end
