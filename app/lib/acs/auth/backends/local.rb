module Acs
  module Auth
    module Backends
      # Username and password held in the ACS users table.
      #
      # Verification goes through User#password_matches?, so the configured
      # crypto provider and the Sha512 -> SCrypt transition still apply while
      # the check itself stays free of side effects: nothing here may start a
      # session, because the resolver has not yet decided whether one is
      # allowed. The failed_login_count bookkeeping Authlogic did inside its
      # own credential path is done here instead, since sessions are now
      # established from an Identity rather than from raw credentials.
      class Local < Backend
        def kind
          :password
        end

        def name
          config[:name].presence || 'Password'
        end

        def enabled?
          # Enabled unless explicitly switched off: an ACS with no working
          # backend at all is worse than one with a password form.
          config.key?(:enabled) ? super : true
        end

        def authenticate(login:, password:)
          user = find_user(login)
          return record_failure(user) unless user&.password_matches?(password)

          record_success(user)
          identity_for(user)
        end

        # No #directory: Acs::Auth.directories always includes the local users
        # table, so exposing it here as well would search it twice.

        private

        def find_user(login)
          return nil if login.blank?

          ::User.find_by_smart_case_login_field(login.to_s)
        end

        def identity_for(user)
          Identity.new(
            provider: key,
            uid: user.login,
            email: user.email,
            login: user.login,
            first_name: user.first_name,
            last_name: user.last_name,
            user: user
          )
        end

        def record_failure(user)
          return nil unless user.respond_to?(:failed_login_count)

          user.update_column(:failed_login_count, user.failed_login_count.to_i + 1)
          nil
        end

        def record_success(user)
          return unless user.respond_to?(:failed_login_count) && user.failed_login_count.to_i.positive?

          user.update_column(:failed_login_count, 0)
        end
      end
    end
  end
end
