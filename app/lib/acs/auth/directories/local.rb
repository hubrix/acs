module Acs
  module Auth
    module Directories
      # The users already in ACS.
      #
      # Always consulted, on top of whatever remote directory is configured.
      # The Rails 3 code only ever asked LDAP, so with LDAP switched off it
      # would happily hand out a login that another ACS user already had and
      # then fail the uniqueness validation.
      class Local < Directory
        def enabled?
          true
        end

        def logins_starting_with(prefix)
          return [] if prefix.blank?

          ::User.where('users.login ilike ?', "#{sanitize(prefix)}%").pluck(:login).compact
        end

        def find_by_email(email)
          return nil if email.blank?

          user = ::User.find_by('lower(users.email) = ?', email.to_s.downcase)
          return nil unless user

          Identity.new(
            provider: 'local',
            uid: user.login,
            email: user.email,
            login: user.login,
            first_name: user.first_name,
            last_name: user.last_name
          )
        end

        private

        def sanitize(prefix)
          prefix.to_s.gsub(/[%_\\]/) { |char| "\\#{char}" }
        end
      end
    end
  end
end
