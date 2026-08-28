source 'https://rubygems.org'

ruby file: '.ruby-version'

gem 'rails', '~> 8.1.0'

# Database
gem 'pg', '~> 1.6'

# Web server
gem 'puma', '~> 8.0'

# Assets
gem 'propshaft', '~> 1.2'
gem 'importmap-rails', '~> 2.2'
gem 'dartsass-rails', '~> 0.5'

# Boot time
gem 'bootsnap', require: false

# Authentication (replaces Authlogic 2.1.6)
gem 'authlogic', '~> 6.6'
gem 'bcrypt', '~> 3.1'
gem 'scrypt', '~> 3.0'

# Authentication backends. OmniAuth drives every redirect-based provider;
# the Google Admin SDK backs directory lookups for Google Workspace.
gem 'omniauth', '~> 2.1'
gem 'omniauth-rails_csrf_protection', '~> 2.0'
gem 'omniauth-google-oauth2', '~> 1.2'
gem 'omniauth_openid_connect', '~> 0.8'
gem 'google-apis-admin_directory_v1', '~> 0.80'
gem 'googleauth', '~> 1.17'

# State machines (replaces aasm 2.2.0)
gem 'aasm', '~> 6.0'

# Org-chart tree on users (replaces the vendored plugin)
gem 'awesome_nested_set', '~> 3.9'

# Pagination
gem 'will_paginate', '~> 4.0'

# Full-text search over Postgres (replaces thinking-sphinx/Sphinx daemon)
gem 'pg_search', '~> 2.3'

# Production error reporting (replaces exception_notifier 1.0.0)
gem 'exception_notification', '~> 5.0'

# Timezone data for the Docker image
gem 'tzinfo-data', platforms: %i[windows jruby]

# No longer default gems as of Ruby 3.4 (csv is used by the employee importer).
gem 'bigdecimal'
gem 'csv'

group :development, :test do
  gem 'rspec-rails', '~> 8.0'
  # assigns / render_template in controller specs
  gem 'rails-controller-testing', '~> 1.0'
  gem 'cucumber-rails', '~> 4.1', require: false
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.47'
  gem 'database_cleaner-active_record', '~> 2.2'
  gem 'launchy', '~> 3.1'
  gem 'debug', require: 'debug/prelude'
end

group :development do
  gem 'web-console'
  gem 'listen', '~> 3.9'
end
