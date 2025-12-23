# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name        = "seed_dump"
  s.version     = File.read(File.join(File.dirname(__FILE__), 'VERSION')).strip
  s.authors     = ["Rob Halff", "Ryan Oblak"]
  s.email       = "rroblak@gmail.com"
  s.homepage    = "https://github.com/rroblak/seed_dump"
  s.summary     = "Seed Dumper for Rails"
  s.description = "Dump (parts) of your database to db/seeds.rb to get a headstart creating a meaningful seeds.rb file"
  s.license     = "MIT"
  s.date        = Time.now.utc.strftime('%Y-%m-%d')

  # Only include essential files in the gem package
  s.files = Dir[
    "lib/**/*",
    "MIT-LICENSE",
    "README.md"
  ]
  s.require_paths = ["lib"]

  # Runtime dependencies
  s.add_runtime_dependency "activerecord", ">= 4"
  s.add_runtime_dependency "activesupport", ">= 4"

  # Development dependencies
  s.add_development_dependency "byebug", "~> 11.1"
  s.add_development_dependency "factory_bot", "~> 6.1"
  s.add_development_dependency "activerecord-import", "~> 0.28"
  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "database_cleaner-active_record", "~> 2.0"
  s.add_development_dependency "appraisal", "~> 2.4"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3", ">= 1.3"

  # Ruby 3.4+ stdlib shims (gems removed from stdlib)
  s.add_development_dependency "mutex_m"
  s.add_development_dependency "logger"
  s.add_development_dependency "benchmark"
  s.add_development_dependency "base64"
end
