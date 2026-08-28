module Acs
  module Auth
    # Derives the login for a new employee: first initial + last name, with a
    # number appended when that is taken ("jdoe", "jdoe1", "jdoe2").
    #
    # This was Acs::Ldap#generate_unique_login. Two things changed:
    #
    #   * it asks every configured directory, including the local users table.
    #     The old version only asked LDAP, so with LDAP switched off it would
    #     hand out a login another ACS user already had and then fail the
    #     uniqueness validation.
    #   * it takes the highest numeric suffix in use rather than reading the
    #     suffix off whichever record the directory happened to return last,
    #     which could reissue a login that already existed.
    class LoginNameGenerator
      def initialize(first_name:, last_name:, directories: nil)
        @first_name = first_name.to_s
        @last_name = last_name.to_s
        @directories = directories
      end

      def self.call(...)
        new(...).call
      end

      def call
        return nil if first_name.blank? || last_name.blank?
        return base if taken.empty?

        "#{base}#{next_suffix}"
      end

      # first initial + last name, e.g. "jdoe"
      def base
        @base ||= "#{first_name[0].downcase}#{last_name.downcase}"
      end

      private

      attr_reader :first_name, :last_name

      def directories
        @directories ||= Acs::Auth.directories
      end

      # Logins that are exactly the base name or the base name plus digits.
      # A prefix search also returns things like "jdoehnson", which must not
      # influence the numbering.
      def taken
        @taken ||= begin
          pattern = /\A#{Regexp.escape(base)}(\d*)\z/i
          candidates.filter_map { |login| Regexp.last_match(1) if login.match(pattern) }
        end
      end

      def candidates
        directories.flat_map do |directory|
          directory.logins_starting_with(base)
        rescue StandardError => e
          # A directory outage must not block hiring someone. The login
          # uniqueness validation still guards against a local collision.
          Rails.logger.warn do
            "Acs::Auth: #{directory.class} could not be searched for '#{base}': #{e.class}: #{e.message}"
          end
          []
        end.uniq
      end

      def next_suffix
        taken.filter_map { |suffix| suffix.presence&.to_i }.max.to_i + 1
      end
    end
  end
end
