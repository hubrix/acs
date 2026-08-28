require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Serve static files from public/ (Propshaft-digested assets live there after
  # `rails assets:precompile`). Set RAILS_SERVE_STATIC_FILES=false when a
  # front-end server such as nginx handles them instead.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].presence != 'false'
  config.assets.compile = false if config.respond_to?(:assets)

  # Replaces the Rack::SslEnforcer middleware from the Rails 3 app.
  config.force_ssl = ENV.fetch('FORCE_SSL', 'true') == 'true'
  config.assume_ssl = ENV.fetch('ASSUME_SSL', 'false') == 'true'

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')
  config.silence_healthcheck_path = '/up'
  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store if defined?(SolidCache)

  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = {
    host: App.email[:host],
    protocol: App.email[:protocol]
  }
  config.action_mailer.smtp_settings = {
    address: App.email[:smtp][:address],
    port: App.email[:smtp].fetch(:port, 25),
    domain: App.email[:smtp][:domain],
    enable_starttls_auto: false
  }

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]

  config.hosts << ENV['APP_HOST'] if ENV['APP_HOST'].present?
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }

  config.middleware.use ExceptionNotification::Rack,
                        email: {
                          email_prefix: App.email[:exceptions][:prefix],
                          sender_address: App.email[:from],
                          exception_recipients: Array(App.email[:exceptions][:recipients])
                        }
end
