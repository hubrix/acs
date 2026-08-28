module Acs
  module Auth
    module Backends
      # Any OpenID Connect provider: Okta, Entra ID, Auth0, Keycloak,
      # JumpCloud, OneLogin.
      #
      # This exists so that adding a second identity provider is configuration
      # rather than code -- the point of the abstraction, given that not every
      # organisation manages its people in Google Workspace.
      #
      #   openid_connect:
      #     enabled: true
      #     name: Okta
      #     issuer: https://example.okta.com
      #     client_id: <%= ENV['OIDC_CLIENT_ID'] %>
      #     client_secret: <%= ENV['OIDC_CLIENT_SECRET'] %>
      #     scope: [openid, email, profile]
      #     discovery: true
      #     allowed_email_domains: [example.com]
      class OpenidConnect < Backend
        DEFAULT_SCOPE = %w[openid email profile].freeze

        def kind
          :redirect
        end

        def name
          config[:name].presence || 'Single sign-on'
        end

        def misconfigured_reason
          return 'issuer is not set' if config[:issuer].blank?
          return 'client_id is not set' if config[:client_id].blank?
          return 'client_secret is not set' if config[:client_secret].blank?

          nil
        end

        def omniauth_provider
          :openid_connect
        end

        def omniauth_args
          [{
            name: key,
            issuer: config[:issuer],
            discovery: discovery?,
            scope: scope,
            response_type: :code,
            client_options: {
              identifier: config[:client_id],
              secret: config[:client_secret],
              redirect_uri: config[:redirect_uri].presence
            }.compact
          }]
        end

        def identity_from(auth_hash)
          auth_hash = auth_hash.with_indifferent_access
          info = auth_hash[:info] || {}
          email = info[:email]

          return nil unless email_domain_allowed?(email)

          Identity.new(
            provider: key,
            uid: auth_hash[:uid],
            email: email,
            first_name: info[:first_name].presence || split_name(info[:name]).first,
            last_name: info[:last_name].presence || split_name(info[:name]).last,
            raw: auth_hash
          )
        end

        private

        def discovery?
          value = config[:discovery]
          value.nil? ? true : ActiveModel::Type::Boolean.new.cast(value)
        end

        def scope
          Array(config[:scope].presence || DEFAULT_SCOPE).map(&:to_sym)
        end

        def allowed_email_domains
          Array(config[:allowed_email_domains]).map { |domain| domain.to_s.downcase }
        end

        def email_domain_allowed?(email)
          return false if email.blank?
          return true if allowed_email_domains.empty?

          allowed_email_domains.include?(email.to_s.downcase.split('@').last)
        end

        # Providers that only send a display name.
        def split_name(name)
          parts = name.to_s.split(/\s+/)
          return [nil, nil] if parts.empty?

          [parts.first, (parts.length > 1 ? parts.last : nil)]
        end
      end
    end
  end
end
