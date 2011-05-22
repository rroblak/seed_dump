# SeedDump
module SeedDump 
  require 'seed_dump/railtie' if defined?(Rails)
  require 'seed_dump/perform' if defined?(Rails)
end
