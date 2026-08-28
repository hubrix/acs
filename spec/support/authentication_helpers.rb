require 'authlogic/test_case'

# Signs a fixture user in for controller specs.
#
# Authlogic's own test helper stores the session on a mock controller, which
# the real controller under test never sees, so the controller's lookup methods
# are stubbed instead.
module AuthenticationHelpers
  extend ActiveSupport::Concern

  included do
    include Authlogic::TestCase

    before { activate_authlogic }
  end

  def sign_in(user)
    user_session = UserSession.create(user)
    allow(controller).to receive(:current_user_session).and_return(user_session)
    allow(controller).to receive(:current_user).and_return(user)
    user
  end
end
