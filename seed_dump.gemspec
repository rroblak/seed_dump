# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

# stub: seed_dump 3.3.1 ruby lib

Gem::Specification.new do |s|
  s.name = 'seed_dump'.freeze
  s.version = '3.3.1'

  s.required_rubygems_version = Gem::Requirement.new('>= 0'.freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib'.freeze]
  s.authors = ['Rob Halff'.freeze, 'Ryan Oblak'.freeze]
  s.description = 'Dump (parts) of your database to db/seeds.rb to get a headstart creating a meaningful seeds.rb file'.freeze
  s.email = 'rroblak@gmail.com'.freeze
  s.extra_rdoc_files = [
    'README.md'
  ]
  s.files = [
    '.rspec',
    'Gemfile',
    'MIT-LICENSE',
    'README.md',
    'Rakefile',
    'VERSION',
    'lib/seed_dump.rb',
    'lib/seed_dump/dump_methods.rb',
    'lib/seed_dump/dump_methods/enumeration.rb',
    'lib/seed_dump/environment.rb',
    'lib/seed_dump/railtie.rb',
    'lib/tasks/seed_dump.rake',
    'seed_dump.gemspec',
    'spec/dump_methods_spec.rb',
    'spec/environment_spec.rb',
    'spec/factories/another_samples.rb',
    'spec/factories/samples.rb',
    'spec/factories/yet_another_samples.rb',
    'spec/helpers.rb',
    'spec/spec_helper.rb'
  ]
  s.homepage = 'https://github.com/rroblak/seed_dump'.freeze
  s.licenses = ['MIT'.freeze]
  s.rubygems_version = '2.7.6'.freeze
  s.summary = '{Seed Dumper for Rails}'.freeze

  s.add_runtime_dependency('activesupport'.freeze, ['>= 4'])
  s.add_runtime_dependency('activerecord'.freeze, ['>= 4'])
  s.add_dependency('byebug'.freeze, ['~> 11.0'])
  s.add_development_dependency('factory_bot'.freeze, ['~> 4.8.2'])
  s.add_development_dependency('activerecord-import'.freeze, ['~> 0.4'])
  s.add_development_dependency('jeweler'.freeze, ['~> 2.0'])
end
