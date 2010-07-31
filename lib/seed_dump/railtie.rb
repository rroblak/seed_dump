# SeedDump
require 'seed_dump'
require 'rails'
module SeedDump 
  class Railtie < Rails::Railtie
    railtie_name :seed_dump

    rake_tasks do
      load "tasks/seed_dump.rake"
    end 

  end
end
