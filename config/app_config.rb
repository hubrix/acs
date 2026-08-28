# Application settings loaded from config/app.yml.
#
# Loaded directly from config/application.rb rather than from an initializer so
# that App is available inside config/environments/*.rb, which Rails loads
# before config/initializers/*.rb. Mailers and models also reference App at
# class-definition time.
require 'yaml'
require 'erb'
require 'active_support/core_ext/hash/indifferent_access'

class App
  class MissingConfig < StandardError; end

  PATH = File.expand_path('app.yml', __dir__)
  EXAMPLE_PATH = File.expand_path('app.yml.example', __dir__)

  class << self
    def config
      @config ||= load_config
    end

    def [](key)
      config[key]
    end

    def key?(key)
      config.key?(key)
    end

    # App.email, App.auth, App.csv, ... read straight off the YAML for the
    # current environment.
    def method_missing(name, *args)
      return super unless args.empty?

      if config.key?(name.to_s)
        config[name.to_s]
      else
        warn "App received message '#{name}' but it is not defined in #{PATH}"
        nil
      end
    end

    def respond_to_missing?(name, include_private = false)
      config.key?(name.to_s) || super
    end

    def reload!
      @config = nil
      config
    end

    private

    def load_config
      path = File.exist?(PATH) ? PATH : EXAMPLE_PATH

      unless File.exist?(path)
        raise MissingConfig, "Neither #{PATH} nor #{EXAMPLE_PATH} exists. " \
                             'Copy config/app.yml.example to config/app.yml.'
      end

      raw = YAML.safe_load(
        ERB.new(File.read(path)).result,
        permitted_classes: [Symbol],
        aliases: true
      )

      env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      settings = raw[env]

      unless settings
        raise MissingConfig, "#{path} has no '#{env}' section (found: #{raw.keys.join(', ')})"
      end

      settings.with_indifferent_access
    end
  end
end
