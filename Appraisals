# Appraisals file for testing seed_dump against different Rails versions.
# Gems defined here are combined with the main Gemfile.
# Gems specified here take precedence over the Gemfile versions for that appraisal.

# Appraisal for Rails 6.1.x
appraise 'rails-6.1' do
  # Specify gems specific to this appraisal scenario
  gem 'activerecord', '~> 6.1.0'
  gem 'activesupport', '~> 6.1.0'
  gem 'sqlite3', '>= 1.3', '< 2.0' # Broadly compatible range
end

# Appraisal for Rails 7.0.x
appraise 'rails-7.0' do
  # Specify gems specific to this appraisal scenario
  gem 'activerecord', '~> 7.0.0'
  gem 'activesupport', '~> 7.0.0'
  gem 'sqlite3', '>= 1.3', '< 2.0' # Broadly compatible range
end

# Appraisal for Rails 7.1.x
appraise 'rails-7.1' do
  # Specify gems specific to this appraisal scenario
  gem 'activerecord', '~> 7.1.0'
  gem 'activesupport', '~> 7.1.0'
  gem 'sqlite3', '>= 1.3', '< 2.0' # Broadly compatible range
end

# Appraisal for Rails 7.2.x
appraise 'rails-7.2' do
  gem 'activerecord', '~> 7.2.0'
  gem 'activesupport', '~> 7.2.0'
  gem 'sqlite3', '>= 1.3', '< 2.0'
end

# Appraisal for Rails 8.0.x (Edge/Main)
appraise 'rails-8.0' do
  # Specify gems specific to this appraisal scenario
  gem 'activerecord', '>= 8.0.0.alpha', '< 8.1'
  gem 'activesupport', '>= 8.0.0.alpha', '< 8.1'

  # Override sqlite3 constraint for Rails 8 compatibility
  # Rails 8 requires sqlite3 >= 2.1
  gem 'sqlite3', '>= 2.1'
end

# Common test gems (rspec, factory_bot, etc.) are inherited from the main Gemfile's :test group.
