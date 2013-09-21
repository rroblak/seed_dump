require 'seed_dump/perform'

class SeedDump
  include SeedDump::Perform

  require 'seed_dump/railtie' if defined?(Rails)
end
