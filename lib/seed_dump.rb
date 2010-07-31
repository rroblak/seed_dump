# SeedDump
module SeedDump 
  #class Engine < Rails::Engine ( < Rails::Railtie )
  class Railtie < Rails::Railtie
    rake_tasks do
      load "lib/tasks/tasks.rake"
    end 
  end
end
