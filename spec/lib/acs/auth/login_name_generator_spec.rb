require 'rails_helper'

RSpec.describe Acs::Auth::LoginNameGenerator do
  # A directory that answers from a fixed list, standing in for Google.
  def directory_with(*logins)
    Class.new(Acs::Auth::Directory) do
      define_method(:logins) { logins.flatten }
      def enabled? = true
      def logins_starting_with(prefix)
        self.logins.select { |login| login.start_with?(prefix) }
      end
    end.new
  end

  def generate(first_name: 'Jane', last_name: 'Doe', directories: [])
    described_class.call(first_name: first_name, last_name: last_name, directories: directories)
  end

  it 'is first initial plus last name' do
    expect(generate).to eq('jdoe')
  end

  it 'downcases whatever it was given' do
    expect(generate(first_name: 'JANE', last_name: 'DOE')).to eq('jdoe')
  end

  it 'returns nil when it has nothing to work from' do
    expect(generate(first_name: '', last_name: 'Doe')).to be_nil
    expect(generate(first_name: 'Jane', last_name: nil)).to be_nil
  end

  describe 'when the name is taken' do
    it 'appends 1' do
      expect(generate(directories: [directory_with('jdoe')])).to eq('jdoe1')
    end

    it 'takes the next number after the highest in use' do
      expect(generate(directories: [directory_with('jdoe', 'jdoe1', 'jdoe2')])).to eq('jdoe3')
    end

    # The Rails 3 version read the suffix off whichever record the directory
    # returned last, so an unordered response could hand back a login that
    # already existed.
    it 'does not depend on the order the directory answers in' do
      expect(generate(directories: [directory_with('jdoe2', 'jdoe', 'jdoe1')])).to eq('jdoe3')
    end

    it 'fills the gap above the highest rather than reusing a freed number' do
      expect(generate(directories: [directory_with('jdoe1')])).to eq('jdoe2')
    end

    # A prefix search also returns "jdoehnson", which must not affect numbering.
    it 'ignores logins that merely start with the same letters' do
      expect(generate(directories: [directory_with('jdoehnson', 'jdoerr')])).to eq('jdoe')
    end

    it 'combines what several directories know' do
      directories = [directory_with('jdoe'), directory_with('jdoe1')]
      expect(generate(directories: directories)).to eq('jdoe2')
    end
  end

  describe 'against the real local directory' do
    it 'sees users already in ACS' do
      # The Rails 3 code only asked LDAP, so with LDAP off it would hand out a
      # login that an ACS user already had.
      expect(described_class.call(first_name: 'Roland', last_name: 'Cooper',
                                  directories: [Acs::Auth::Directories::Local.new]))
        .to eq('rcooper1')
    end

    it 'is what User#generate_unique_login uses' do
      user = User.new(first_name: 'Roland', last_name: 'Cooper')
      expect(user.generate_unique_login).to eq('rcooper1')
    end

    it 'treats the search prefix as a literal, not a LIKE pattern' do
      expect { described_class.call(first_name: 'A', last_name: '%_x',
                                    directories: [Acs::Auth::Directories::Local.new]) }
        .not_to raise_error
    end
  end

  describe 'when a directory is unreachable' do
    let(:broken) do
      Class.new(Acs::Auth::Directory) do
        def enabled? = true
        def logins_starting_with(_prefix) = raise(IOError, 'directory is down')
      end.new
    end

    # A Google outage must not stop HR hiring someone; the login uniqueness
    # validation still guards against a local collision.
    it 'carries on with what the other directories know' do
      expect(generate(directories: [broken, directory_with('jdoe')])).to eq('jdoe1')
    end

    it 'says so in the log' do
      expect(Rails.logger).to receive(:warn)
      generate(directories: [broken])
    end
  end
end
