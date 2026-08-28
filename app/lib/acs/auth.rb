module Acs
  # Authentication backends.
  #
  # Replaces the hardcoded LDAP integration. Backends are declared in
  # config/app.yml under `auth.backends`; each entry names a backend class and
  # carries its own settings:
  #
  #   auth:
  #     backends:
  #       local:
  #         enabled: true
  #       google_workspace:
  #         enabled: true
  #         client_id: ...
  #
  # More than one may be enabled at once, so the login page can offer a
  # password form alongside one or more "Sign in with ..." buttons.
  module Auth
    class Error < StandardError; end
    class ConfigurationError < Error; end

    # Adding a backend: subclass Acs::Auth::Backend and add it here.
    BACKEND_CLASSES = {
      'local' => 'Acs::Auth::Backends::Local',
      'google_workspace' => 'Acs::Auth::Backends::GoogleWorkspace',
      'openid_connect' => 'Acs::Auth::Backends::OpenidConnect'
    }.freeze

    class << self
      def config
        raw = App.respond_to?(:auth) ? App.auth : nil
        (raw || {}).with_indifferent_access
      end

      # Every configured backend, enabled or not, in config order.
      def all_backends
        @all_backends ||= build_backends
      end

      # The backends actually available for signing in.
      def backends
        all_backends.select(&:usable?)
      end

      def find(key)
        all_backends.detect { |backend| backend.key == key.to_s }
      end

      def usable(key)
        backend = find(key)
        backend if backend&.usable?
      end

      def password_backends
        backends.select(&:password?)
      end

      def redirect_backends
        backends.select(&:redirect?)
      end

      def local_passwords_enabled?
        password_backends.any?
      end

      # True when a user can only get in through an identity provider, which
      # is when the password field stops being meaningful.
      def redirect_only?
        password_backends.empty? && redirect_backends.any?
      end

      # Tries each enabled password backend in order and returns the first
      # Identity produced. Returns nil when none of them accept.
      def authenticate(login:, password:)
        return nil if login.blank? || password.blank?

        password_backends.lazy.filter_map do |backend|
          backend.authenticate(login: login, password: password)
        end.first
      end

      # The account directory used when generating logins: whatever remote
      # directory is configured, plus the local users table.
      def directories
        remote = backends.filter_map(&:directory).select(&:enabled?)
        remote + [Directories::Local.new]
      end

      # The "actor-target" login that signs in as one user and sessions as
      # another. A support convenience, off unless explicitly enabled.
      def impersonation_enabled?
        ActiveModel::Type::Boolean.new.cast(config[:impersonation]) || false
      end

      # Problems worth surfacing to an operator rather than failing silently at
      # sign-in time.
      def warnings
        all_backends.select(&:enabled?).filter_map do |backend|
          reason = backend.misconfigured_reason
          "auth backend '#{backend.key}' is enabled but unusable: #{reason}" if reason
        end
      end

      def reload!
        @all_backends = nil
      end

      private

      def build_backends
        entries = config[:backends] || {}
        entries.map do |key, backend_config|
          class_name = BACKEND_CLASSES[key.to_s]
          unless class_name
            raise ConfigurationError,
                  "unknown auth backend '#{key}' in config/app.yml " \
                  "(known: #{BACKEND_CLASSES.keys.join(', ')})"
          end

          class_name.constantize.new(key, backend_config)
        end
      end
    end
  end
end
