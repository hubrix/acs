def log_in_as(username)
  visit '/'
  fill_in 'Login', with: username
  fill_in 'Password', with: 'asdfasdf'
  click_button 'Login'
end

def signed_in_user
  UserSession.find&.user
end

Given(/^I am logged in as "([^"]*)"$/) do |username|
  log_in_as(username)
  expect(page).to have_content('Hello')
  expect(page).to have_content('Dashboard')
  @current_user = User.find_by!(login: username)
end

Then(/^I login as "([^"]*)"$/) do |username|
  log_in_as(username)
  @current_user = User.find_by!(login: username)
end

Given(/^I am not logged in$/) do
  expect(signed_in_user).to be_nil
end

Given(/^I have the role "([^"]*)"$/) do |role|
  expect(@current_user.roles).to include(roles(role.to_sym))
end

Given(/^I am a manager$/) do
  expect(@current_user).to be_manager
end

Given(/^I am not a manager$/) do
  expect(@current_user.manager_flag).to be(false)
  expect(@current_user.descendants).to be_blank
end

Given(/^"([^"]*)" is subordinate to "([^"]*)"$/) do |employee, manager|
  @employee = User.find_by!(login: employee)
  @manager = User.find_by!(login: manager)
  expect(@manager.subordinates).to include(@employee)
end

Given(/^"([^"]*)" is my subordinate$/) do |username|
  @user = User.find_by!(login: username)
  expect(@current_user.subordinates).to include(@user)
end

Then(/^(?:|I )check permission "([^"]*)"$/) do |permission|
  check("resources_permission_ids_#{permissions(permission.to_sym).id}")
end

Then(/^the checkbox for "([^"]*)" should be disabled$/) do |permission|
  id = "access_request_permission_requests_attributes_permission_id_#{permissions(permission.to_sym).id}"
  expect(page).to have_field(id, disabled: true)
end

Then(/^the checkbox for permission "([^"]*)" should be disabled$/) do |permission_id|
  expect(page).to have_field("user_permission_ids_#{permission_id}", disabled: true)
end

Then(/^the access request "([^"]*)" should be "([^"]*)"$/) do |access_request, state|
  expect(access_requests(access_request.to_sym).reload.current_state).to eq(state)
end

Then(/^the user "([^"]*)" should be "([^"]*)"$/) do |login, state|
  @user = User.find_by!(login: login)
  expect(@user.reload.current_state).to eq(state)
end

Then(/^there should be (\d+) access request for "([^"]*)"$/) do |number, username|
  @user = User.find_by!(login: username)
  expect(@user.access_requests.not_completed.size).to eq(number.to_i)
  @access_request = @user.access_requests.not_completed.last
end

Then(/^the requests access requests should request to "([^"]*)"$/) do |request_action|
  @request.reload
  expect(@request.access_requests.map(&:request_action).uniq).to eq([request_action])
end

Then(/^the requests access requests should be assigned to "([^"]*)"$/) do |username|
  @request.reload
  user = User.find_by!(login: username)
  expect(@request.access_requests.map(&:current_worker).uniq).to eq([user])
end

Then(/^the request reason should be "([^"]*)"$/) do |reason|
  expect(@request.reload.reason).to eq(reason)
end

Then(/^the request state should be "([^"]*)"$/) do |current_state|
  expect(@request.reload.current_state).to eq(current_state)
end

Then(/^the request should be created by "([^"]*)"$/) do |login|
  expect(@request.reload.created_by.login).to eq(login)
end

Then(/^the request should be by manager for subordinate$/) do
  expect(@request.reload).to be_created_by_manager_for_subordinate
end

Then(/^the user should have (\d+) access requests$/) do |number|
  expect(@user.reload.access_requests.size).to eq(number.to_i)
end

Then(/^the access request should be unassigned$/) do
  expect(@access_request.reload.current_worker).to be_nil
end

Then(/^the permission request should be for "([^"]*)"$/) do |permission|
  @permission_request = @access_request.permission_requests.first
  expect(@permission_request.permission).to eq(permissions(permission.to_sym))
end

Then(/^all permission requests should be approved by "([^"]*)"$/) do |role|
  @request.reload
  approvals = @request.permission_requests.map { |pr| pr.public_send("approved_by_#{role}") }
  expect(approvals.uniq).to eq([true])
end

Then(/^all permission requests should not be approved by "([^"]*)"$/) do |role|
  @request.reload
  approvals = @request.permission_requests.map { |pr| pr.public_send("approved_by_#{role}") }
  expect(approvals.compact).to be_empty
end

# The dashboard can list the same record in more than one panel, so these ids
# are not unique on the page. webrat's click_link took the first match.
Given(/^I follow the link for "([^"]*)"$/) do |request|
  first("#dashboard_request_#{requests(request.to_sym).id}").click
end

Then(/^I follow the access request link for "([^"]*)"$/) do |access_request|
  first("#dashboard_access_request_#{access_requests(access_request.to_sym).id}").click
end

Given(/^I follow the link to user "([^"]*)"$/) do |user|
  @user = users(user.to_sym)
  first("#users_#{@user.id}").click
end

When(/^I visit the show access request page for "([^"]*)"$/) do |access_request|
  visit access_request_path(access_requests(access_request.to_sym))
end
