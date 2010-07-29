# SeedDump
module SeedDump 
  class Railtie < Rails::Railtie
    rake_tasks do
      load "seed_dump/railties/tasks.rake"
    end 
  end
end
