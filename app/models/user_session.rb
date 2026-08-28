# Authlogic session.
#
# Password verification now lives in Acs::Auth::Backends::Local rather than in
# a verify_password_method here, because sessions are created from a resolved
# user (UserSession.create(user)) regardless of which backend authenticated
# them. Authlogic is still responsible for the cookie, the persistence token
# and the login_count/current_login_at magic columns.
class UserSession < Authlogic::Session::Base
end
