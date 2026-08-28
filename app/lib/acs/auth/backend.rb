module Acs
  module Auth
    # Base class for an authentication backend.
    #
    # A backend is one of two kinds:
    #
    #   :password  the user hands us a login and a password and we verify them
    #              ourselves. Implement #authenticate.
    #
    #   :redirect  the user is sent to an identity provider and comes back with
    #              an OmniAuth auth hash. Implement #omniauth_provider,
    #              #omniauth_options and #identity_from.
    #
    # Either kind may also expose a Directory, which is how the app looks up
    # accounts that exist at the provider but not yet in ACS -- used when
    # generating a login for a new employee.
    #
    # Adding a backend means subclassing this, returning an Identity, and
    # registering the class in Acs::Auth::BACKEND_CLASSES.
    class Backend
      attr_reader :key, :config

      def initialize(key, config = {})
        @key = key.to_s
        @config = (config || {}).with_indifferent_access
      end

      # Shown on the login page.
      def name
        config[:name].presence || key.humanize
      end

      def kind
        raise NotImplementedError, "#{self.class} must declare a kind"
      end

      def password?
        kind == :password
      end

      def redirect?
        kind == :redirect
      end

      def enabled?
        ActiveModel::Type::Boolean.new.cast(config[:enabled]) || false
      end

      # Backends that cannot work with the configuration they were given say so
      # here rather than failing at sign-in time.
      def misconfigured_reason
        nil
      end

      def usable?
        enabled? && misconfigured_reason.nil?
      end

      # --- :password backends ---------------------------------------------

      # Returns an Identity, or nil when the credentials are wrong.
      def authenticate(login:, password:)
        raise NotImplementedError, "#{self.class} is not a password backend"
      end

      # --- :redirect backends ---------------------------------------------

      # The OmniAuth strategy name, e.g. :google_oauth2.
      def omniauth_provider
        raise NotImplementedError, "#{self.class} is not a redirect backend"
      end

      # Positional and keyword arguments for OmniAuth::Builder#provider.
      def omniauth_args
        []
      end

      # The path the login page posts to in order to start the flow. Backends
      # share a strategy name only if they are the same provider, so the key is
      # used as the OmniAuth `name` to keep them distinct.
      def start_path
        "/auth/#{key}"
      end

      # Turns an OmniAuth auth hash into an Identity. Returning nil rejects the
      # sign-in (for example a Google account outside the hosted domain).
      def identity_from(auth_hash)
        raise NotImplementedError, "#{self.class} is not a redirect backend"
      end

      # --- directory -------------------------------------------------------

      # An Acs::Auth::Directory, or nil when this backend cannot enumerate
      # accounts.
      def directory
        nil
      end

      def to_s
        "#{self.class.name}(#{key})"
      end
    end
  end
end
