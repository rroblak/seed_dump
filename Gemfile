source 'https://rubygems.org'

# Runtime dependencies (also used in test appraisals)
gem 'activesupport', '>= 4'
gem 'activerecord', '>= 4'

group :development, :test do
  # Common development and test dependencies
  gem 'byebug', '~> 11.1'
  gem 'factory_bot', '~> 6.1'
  # activerecord-import might be needed for tests if using :import option
  gem 'activerecord-import', '~> 0.28'
end

group :development do
  # Development-only dependencies
  gem 'jeweler', '~> 2.3'
end

group :test do
  # Test-only dependencies (common across all appraisals)
  gem 'rspec', '~> 3.7.0'
  gem 'database_cleaner-active_record', '~> 2.0'
  gem 'appraisal', '~> 2.4'

  # Add gems removed from Ruby stdlib/default but needed by older ActiveSupport
  # Required for Ruby 3.4+
  gem 'mutex_m'
  # Recommended for Ruby 3.5+ (or to silence warning in 3.4)
  gem 'logger'
  # Add benchmark to silence Ruby 3.5+ warning
  gem 'benchmark'
end

# Pull in dependencies specified in the gemspec
gemspec
