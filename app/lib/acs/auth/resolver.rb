module Acs
  module Auth
    # Maps an Identity onto the ACS user it belongs to.
    #
    # ACS deliberately does not create users from an identity provider: a user
    # here carries a manager, a job and a permission template, and those come
    # from the new-hire workflow, not from a Google profile. So an identity is
    # only ever matched to a user that already exists:
    #
    #   1. a LinkedAccount for this provider and uid, or
    #   2. an active user whose email matches, which then records the link.
    #
    # Anything else is refused.
    class Resolver
      Result = Struct.new(:user, :error, keyword_init: true) do
        def success?
          user.present?
        end
      end

      def initialize(identity)
        @identity = identity
      end

      def self.call(identity)
        new(identity).call
      end

      def call
        # The local backend already loaded the user to verify the password.
        return from_known_user(identity.user) if identity.user

        linked = LinkedAccount.for_identity(identity)
        return from_link(linked) if linked

        user = user_matching_email
        return failure(no_match_message) unless user
        return failure(inactive_message(user)) unless signin_allowed?(user)

        link!(user)
        success(user)
      end

      private

      attr_reader :identity

      def from_known_user(user)
        return failure(inactive_message(user)) unless signin_allowed?(user)

        success(user)
      end

      def from_link(linked)
        user = linked.user
        return failure(inactive_message(user)) unless signin_allowed?(user)

        linked.touch_authentication!(email: identity.email)
        success(user)
      end

      def user_matching_email
        return nil if identity.email.blank?

        ::User.find_by('lower(users.email) = ?', identity.email)
      end

      # Only currently-employed people get in. Terminated and suspended users
      # keep their records for audit but cannot sign in.
      def signin_allowed?(user)
        user.active?
      end

      def link!(user)
        LinkedAccount.create!(
          provider: identity.provider,
          uid: identity.uid,
          user_id: user.id,
          email: identity.email,
          last_authenticated_at: Time.current
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # Another request won the race; the existing row is equivalent.
        nil
      end

      def success(user)
        Result.new(user: user)
      end

      def failure(message)
        Result.new(error: message)
      end

      def no_match_message
        'That account is not set up in ACS. Ask HR to create your employee ' \
          'record before signing in.'
      end

      def inactive_message(user)
        case user.current_state
        when 'terminated' then 'That employee record has been terminated.'
        when 'suspended' then 'That employee record is suspended pending HR review.'
        when 'pending' then 'That employee record is still waiting on HR confirmation.'
        else 'That employee record is not active.'
        end
      end
    end
  end
end
