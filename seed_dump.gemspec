# encoding: utf-8
require File.expand_path('../lib/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name = 'seed_dump'
  gem.version = SeedDump::VERSION::STRING
  gem.date = Time.now.strftime('%Y-%m-%d')
  
  gem.summary = "Seed Dump for Rails"
  gem.description = "Dump (parts) of your database to db/seeds.rb to get a headstart creating a meaningful seeds.rb file "
  
  gem.authors = ['Rob Halff']
  gem.email = 'rob.halff@gmail.com'
  gem.homepage = 'http://github.com/rhalff/seed_dump/wikis'
  
  gem.rubyforge_project = nil
  gem.has_rdoc = true
  gem.rdoc_options = ['--main', 'README.rdoc', '--charset=UTF-8']
  gem.extra_rdoc_files = ['README.rdoc', 'MIT-LICENSE', 'CHANGELOG.rdoc']
  
  gem.files = Dir['Rakefile', '{lib,test}/**/*', 'README*', 'MIT-LICENSE'] & `git ls-files -z`.split("\0")
end
