namespace :db do
  namespace :seed  do
    desc "Dump records from the database into db/seeds.rb"
    task :dump => :environment do

      SeedDump::Perform::run(ENV)

    end
  end
end
