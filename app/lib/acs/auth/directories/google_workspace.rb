require 'google/apis/admin_directory_v1'
require 'googleauth'

module Acs
  module Auth
    module Directories
      # Account lookups against the Google Workspace Admin SDK.
      #
      # This is the replacement for the LDAP search that told ACS whether a
      # generated login was already taken. A Workspace login is the local part
      # of the primary email, so "jdoe@example.com" occupies the login "jdoe";
      # aliases count too, since they cannot be reused either.
      #
      # Needs a service account with domain-wide delegation, granted
      # https://www.googleapis.com/auth/admin.directory.user.readonly, and an
      # admin to impersonate:
      #
      #   directory:
      #     enabled: true
      #     impersonate: directory-reader@example.com
      #     service_account_json: <%= ENV['GOOGLE_SERVICE_ACCOUNT_JSON'] %>
      #
      # service_account_json is either the JSON itself or a path to it.
      class GoogleWorkspace < Directory
        SCOPE = 'https://www.googleapis.com/auth/admin.directory.user.readonly'.freeze
        MAX_RESULTS = 200

        # Injectable so specs never reach the network.
        attr_writer :service

        def initialize(config = {}, service: nil)
          super(config)
          @service = service
        end

        def enabled?
          super && configured?
        end

        def configured?
          config[:impersonate].present? && credentials_json.present?
        end

        def logins_starting_with(prefix)
          return [] if prefix.blank?

          response = service.list_users(
            domain: domain,
            query: "email:#{escape(prefix)}*",
            max_results: MAX_RESULTS,
            projection: 'basic',
            view_type: 'admin_view'
          )
          Array(response.users).flat_map { |user| logins_for(user) }.compact.uniq
        end

        def find_by_email(email)
          return nil if email.blank?

          user = service.get_user(email.to_s)
          return nil unless user

          Identity.new(
            provider: 'google_workspace',
            uid: user.id,
            email: user.primary_email,
            login: local_part(user.primary_email),
            first_name: user.name&.given_name,
            last_name: user.name&.family_name,
            raw: user
          )
        rescue Google::Apis::ClientError
          nil
        end

        def available?
          service.present?
        rescue StandardError
          false
        end

        def service
          @service ||= build_service
        end

        private

        def domain
          config[:hosted_domain].presence
        end

        def build_service
          service = Google::Apis::AdminDirectoryV1::DirectoryService.new
          service.client_options.application_name = 'ACS'
          service.authorization = authorization
          service
        end

        def authorization
          credentials = Google::Auth::ServiceAccountCredentials.make_creds(
            json_key_io: StringIO.new(credentials_json),
            scope: SCOPE
          )
          # Domain-wide delegation: act as a real admin, not the robot.
          credentials.sub = config[:impersonate]
          credentials.fetch_access_token!
          credentials
        end

        # Accepts the JSON key inline or a path to it on disk.
        def credentials_json
          @credentials_json ||= begin
            value = config[:service_account_json].to_s.strip
            if value.start_with?('{')
              value
            elsif value.present? && File.exist?(value)
              File.read(value)
            else
              ''
            end
          end
        end

        def logins_for(user)
          [user.primary_email, *Array(user.aliases)].compact.map { |email| local_part(email) }
        end

        def local_part(email)
          email.to_s.split('@').first.presence
        end

        # The Admin SDK query language treats these as syntax.
        def escape(prefix)
          prefix.to_s.gsub(/["'\\]/, '')
        end
      end
    end
  end
end
