require 'cucumber/rails'
require 'authlogic/test_case'
require 'rspec/expectations'

# Errors raised inside the app bubble out to the step definition instead of
# rendering an error page. Tag a scenario @allow-rescue to opt out.
ActionController::Base.allow_rescue = false

Capybara.default_selector = :css
# webrat matched against the raw response body; Capybara compares rendered
# text, so collapse the newlines block elements introduce.
Capybara.default_normalize_ws = true
Capybara.default_max_wait_time = 2
Capybara.server = :puma, { Silent: true }

# The features run against the spec/ fixtures, which are reloaded per scenario,
# so the database is truncated rather than rolled back.
begin
  DatabaseCleaner.strategy = :truncation
rescue NameError
  raise 'You need to add database_cleaner-active_record to your Gemfile.'
end

Cucumber::Rails::Database.javascript_strategy = :truncation

World(Authlogic::TestCase)

Before do
  activate_authlogic
  ActionMailer::Base.deliveries.clear
end
