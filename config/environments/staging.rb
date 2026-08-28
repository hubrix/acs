require 'active_support/core_ext/integer/time'

# Staging mirrors production, except that mail is captured rather than sent and
# SSL is not forced (staging often runs behind a plain-HTTP load balancer).
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].presence != 'false'
  config.force_ssl = ENV.fetch('FORCE_SSL', 'false') == 'true'

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'debug')
  config.silence_healthcheck_path = '/up'

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: App.email[:host],
    protocol: App.email[:protocol]
  }

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = true
  config.active_record.dump_schema_after_migration = false

  config.hosts << ENV['APP_HOST'] if ENV['APP_HOST'].present?
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }

  config.middleware.use ExceptionNotification::Rack,
                        email: {
                          email_prefix: App.email[:exceptions][:prefix],
                          sender_address: App.email[:from],
                          exception_recipients: Array(App.email[:exceptions][:recipients])
                        }
end
