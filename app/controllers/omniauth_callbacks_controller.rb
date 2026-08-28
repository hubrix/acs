# Handles the return leg of every redirect auth backend.
#
# OmniAuth has already validated the provider's response and the request-phase
# CSRF token by the time we get here; what is left is turning the auth hash
# into an Identity, resolving it to an ACS user, and starting the session.
class OmniauthCallbacksController < ApplicationController
  # OmniAuth carries its own state parameter through the provider round trip,
  # and some providers (SAML, form_post OIDC) come back as a POST without a
  # Rails CSRF token.
  skip_before_action :verify_authenticity_token, only: %i[create failure]

  def create
    auth = request.env['omniauth.auth']
    backend = auth && Acs::Auth.usable(auth['provider'])
    return refuse('That sign-in method is not available.') if backend.nil?

    identity = backend.identity_from(auth.to_hash)
    if identity.nil?
      return refuse("Your #{backend.name} account is not allowed to sign in here.",
                    log: "#{backend.key} rejected the identity (domain or verification check)")
    end

    result = Acs::Auth::Resolver.call(identity)
    unless result.success?
      return refuse(result.error, log: "#{backend.key} identity #{identity.uid} (#{identity.email}) " \
                                       "could not be resolved: #{result.error}")
    end

    UserSession.create(result.user)
    flash[:notice] = "Signed in with #{backend.name}."
    redirect_back_or_default dashboard_path
  end

  # OmniAuth routes strategy errors here (access denied, invalid state, an
  # unreachable provider).
  def failure
    reason = params[:message].presence || request.env['omniauth.error.type'].presence || 'unknown'
    refuse('Sign-in was not completed. Please try again.', log: "omniauth failure: #{reason}")
  end

  private

  def refuse(message, log: nil)
    Rails.logger.warn { "AUTH REFUSED: #{log || message}" }
    flash[:error] = message
    redirect_to login_path
  end
end
