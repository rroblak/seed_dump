require 'seed_dump/dump_methods'

class SeedDump
  include SeedDump::DumpMethods

  require 'seed_dump/railtie' if defined?(Rails)
end
