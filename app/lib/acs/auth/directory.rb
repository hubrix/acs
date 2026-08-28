module Acs
  module Auth
    # Read-only view of the accounts that exist at an identity provider.
    #
    # This is the half of the old LDAP module that was not about passwords:
    # when a new employee is created, ACS derives a login like "jdoe" and needs
    # to know whether that name is already taken in the directory so it can
    # fall back to "jdoe1", "jdoe2" and so on.
    class Directory
      attr_reader :config

      def initialize(config = {})
        @config = (config || {}).with_indifferent_access
      end

      def enabled?
        ActiveModel::Type::Boolean.new.cast(config[:enabled]) || false
      end

      # Logins already in use that begin with the given prefix.
      def logins_starting_with(_prefix)
        raise NotImplementedError, "#{self.class} must implement #logins_starting_with"
      end

      # An Identity for the given email, or nil. Used to confirm an account
      # still exists at the provider.
      def find_by_email(_email)
        nil
      end

      # True when the directory answered; false when it could not be reached.
      # Callers use this to decide whether an empty result means "no match" or
      # "do not trust this answer".
      def available?
        true
      end
    end
  end
end
