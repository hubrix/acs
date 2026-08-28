module Acs
  module Auth
    module Backends
      # Google Workspace, via OAuth2 sign-in plus the Admin SDK for directory
      # lookups.
      #
      # Configuration (config/app.yml):
      #
      #   google_workspace:
      #     enabled: true
      #     name: Google
      #     client_id: <%= ENV['GOOGLE_CLIENT_ID'] %>
      #     client_secret: <%= ENV['GOOGLE_CLIENT_SECRET'] %>
      #     hosted_domain: example.com
      #     directory:
      #       enabled: true
      #       impersonate: directory-reader@example.com
      #       service_account_json: <%= ENV['GOOGLE_SERVICE_ACCOUNT_JSON'] %>
      #
      # `hosted_domain` is enforced twice: Google is asked to restrict the
      # account chooser to it, and the claim is checked again on the way back,
      # because the `hd` parameter alone is a hint rather than a guarantee.
      class GoogleWorkspace < Backend
        def kind
          :redirect
        end

        def name
          config[:name].presence || 'Google'
        end

        def misconfigured_reason
          return 'client_id is not set' if config[:client_id].blank?
          return 'client_secret is not set' if config[:client_secret].blank?

          nil
        end

        def omniauth_provider
          :google_oauth2
        end

        def omniauth_args
          [
            config[:client_id],
            config[:client_secret],
            {
              name: key,
              scope: 'email,profile',
              hd: hosted_domain.presence,
              prompt: 'select_account',
              access_type: 'online',
              skip_jwt: false
            }.compact
          ]
        end

        def identity_from(auth_hash)
          auth_hash = auth_hash.with_indifferent_access
          info = auth_hash[:info] || {}
          extra = auth_hash.dig(:extra, :raw_info) || {}

          return nil unless email_verified?(extra)
          return nil unless within_hosted_domain?(info[:email], extra)

          Identity.new(
            provider: key,
            uid: auth_hash[:uid],
            email: info[:email],
            first_name: info[:first_name],
            last_name: info[:last_name],
            raw: auth_hash
          )
        end

        def directory
          return nil unless directory_config[:enabled]

          @directory ||= Directories::GoogleWorkspace.new(
            directory_config.merge(hosted_domain: hosted_domain)
          )
        end

        def hosted_domain
          config[:hosted_domain].to_s.downcase.presence
        end

        private

        def directory_config
          @directory_config ||= (config[:directory] || {}).with_indifferent_access
        end

        # Google sets email_verified for Workspace accounts; an unverified
        # address must not be trusted to match an ACS user.
        def email_verified?(extra)
          value = extra[:email_verified]
          return true if value.nil? # older payloads omit it

          ActiveModel::Type::Boolean.new.cast(value)
        end

        def within_hosted_domain?(email, extra)
          return true if hosted_domain.blank?

          claimed = extra[:hd].to_s.downcase
          return true if claimed == hosted_domain

          # Fall back to the address itself: consumer accounts have no hd.
          email.to_s.downcase.split('@').last == hosted_domain
        end
      end
    end
  end
end
