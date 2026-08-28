module Acs
  module Auth
    # What a backend knows about whoever just authenticated, normalised so the
    # rest of the app never sees provider-specific shapes.
    #
    # `uid` is the provider's stable identifier for the account -- Google's
    # `sub` claim, a local user's login -- and is what the LinkedAccount row is
    # keyed on. It deliberately is not the email, which people change.
    class Identity
      attr_reader :provider, :uid, :email, :login, :first_name, :last_name, :raw, :user

      # `user` is set by backends that already hold the ACS record -- the local
      # password backend had to load it to check the password -- so the
      # resolver does not look it up a second time or record a link for an
      # account that is not actually external.
      def initialize(provider:, uid:, email: nil, login: nil, first_name: nil, last_name: nil,
                     raw: nil, user: nil)
        @provider = provider.to_s
        @uid = uid.to_s
        @email = email.presence&.downcase
        @login = login.presence
        @first_name = first_name.presence
        @last_name = last_name.presence
        @raw = raw
        @user = user

        raise ArgumentError, 'an identity needs a provider' if @provider.blank?
        raise ArgumentError, 'an identity needs a uid' if @uid.blank?
      end

      def full_name
        [first_name, last_name].compact.join(' ').presence
      end

      def to_h
        { provider: provider, uid: uid, email: email, login: login,
          first_name: first_name, last_name: last_name }
      end

      def ==(other)
        other.is_a?(Identity) && provider == other.provider && uid == other.uid
      end
      alias eql? ==

      def hash
        [provider, uid].hash
      end

      def inspect
        "#<Acs::Auth::Identity #{provider}:#{uid} #{email}>"
      end
    end
  end
end
