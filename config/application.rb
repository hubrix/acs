require_relative 'boot'

require 'rails'

require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'

# App must be defined before config/environments/*.rb runs, so it is required
# here rather than from an initializer.
require_relative 'app_config'

# Core extensions (Array#chunk_it/#chunker, String#titleize overrides).
require_relative '../lib/core_ext/array'
require_relative '../lib/core_ext/string'

# Require the gems listed in Gemfile, including any gems limited to
# :test, :development, or :production.
Bundler.require(*Rails.groups)

module Acs
  class Application < Rails::Application
    config.load_defaults 8.1

    # This app predates Zeitwerk's `concerns` conventions; its shared model
    # modules live under app/models/acs and app/models/access_requests.
    config.autoload_lib(ignore: %w[assets core_ext tasks console.rb])

    # app/assets/stylesheets holds only Sass sources; dartsass compiles them
    # into app/assets/builds, which is what Propshaft should serve. Left on the
    # load path, the raw .scss files are published alongside the CSS they were
    # compiled into. Propshaft adds every app/assets/* directory in its own
    # initializer, so this has to run after that.
    initializer 'acs.assets.exclude_sass_sources', after: 'propshaft.append_assets_path' do |app|
      sources = app.root.join('app/assets/stylesheets').to_s
      app.config.assets.paths.reject! { |path| path.to_s == sources }
    end

    config.time_zone = 'Central Time (US & Canada)'
    config.active_record.default_timezone = :utc

    config.encoding = 'utf-8'
    config.filter_parameters += %i[password password_confirmation]

    config.generators do |g|
      g.orm :active_record
      g.template_engine :erb
      g.test_framework :rspec, fixture: true, views: false
    end

    # This app is server-rendered ERB with jQuery; it does not use Turbo, and
    # the API-only middleware trimming does not apply.
    config.action_view.form_with_generates_remote_forms = false

    # Legacy schema: this app's tables predate Rails' `id: :bigint` default and
    # several join tables have no primary key.
    config.active_record.schema_format = :ruby
  end
end
