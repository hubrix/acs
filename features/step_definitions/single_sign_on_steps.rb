# OmniAuth is in test mode (features/support/omniauth.rb), so the request phase
# short-circuits straight to the callback with whatever is registered here --
# no identity provider is contacted.

Given(/^Google will authenticate "([^"]*)"(?: with uid "([^"]*)")?$/) do |email, uid|
  OmniAuth.config.mock_auth[:google_workspace] = OmniAuth::AuthHash.new(
    provider: 'google_workspace',
    uid: uid.presence || "google-#{email.hash.abs}",
    info: { email: email, first_name: 'Test', last_name: 'Person' },
    extra: { raw_info: { email: email, email_verified: true, hd: email.split('@').last } }
  )
end

Given(/^the OpenID Connect provider will authenticate "([^"]*)"$/) do |email|
  OmniAuth.config.mock_auth[:openid_connect] = OmniAuth::AuthHash.new(
    provider: 'openid_connect',
    uid: "oidc-#{email.hash.abs}",
    info: { email: email, name: 'Test Person' }
  )
end

Given(/^Google will fail with "([^"]*)"$/) do |reason|
  OmniAuth.config.mock_auth[:google_workspace] = reason.to_sym
end

Given(/^"([^"]*)" has a linked "([^"]*)" account with uid "([^"]*)"$/) do |login, provider, uid|
  LinkedAccount.create!(
    provider: provider,
    uid: uid,
    user: User.find_by!(login: login),
    email: User.find_by!(login: login).email
  )
end

Then(/^"([^"]*)" should have a linked "([^"]*)" account$/) do |login, provider|
  user = User.find_by!(login: login)
  expect(user.linked_accounts.map(&:provider)).to include(provider)
end

Then(/^"([^"]*)" should have (\d+) linked account$/) do |login, count|
  expect(User.find_by!(login: login).linked_accounts.count).to eq(count.to_i)
end
