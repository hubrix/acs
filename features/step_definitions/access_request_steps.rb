Given(/^I do not have any access to the resource "([^"]*)" from resource group "([^"]*)"$/) do |resource, resource_group|
  @resource_group = resource_groups(resource_group.to_sym)
  @resource = @resource_group.resources.find_by!(name: resource)
  expect(@current_user.permissions.map(&:resource)).not_to include(@resource)
end

Given(/^I have "([^"]*)" access for resource "([^"]*)" from resource group "([^"]*)"$/) do |permission, resource, resource_group|
  @resource_group = ResourceGroup.find_by!(name: resource_group)
  @resource = @resource_group.resources.find_by!(name: resource)
  @permission_type = @resource_group.permission_types.find_by!(name: permission)
  @permission = @resource.permissions.find_by!(permission_type_id: @permission_type.id)
  expect(@current_user.permissions).to include(@permission)
end

Given(/^I have a pending access request for "([^"]*)" from resource group "([^"]*)"$/) do |resource, resource_group|
  @resource_group = resource_groups(resource_group.to_sym)
  @resource = @resource_group.resources.find_by!(name: resource)
  open_requests = @current_user.access_requests.not_completed
  expect(open_requests.map(&:resource)).to include(@resource)
end

Given(/^"([^"]*)" is a request created by "([^"]*)"$/) do |name, login|
  @request = requests(name.to_sym)
  @created_by = users(login.to_sym)
  expect(@request.user).to eq(@created_by)
end

Then(/^the access request for "([^"]*)" should request "([^"]*)" access$/) do |resource, permission|
  resource = resources(resource.to_sym)
  access_request = @request.access_requests.find_by!(resource_id: resource.id)
  types = access_request.permission_requests.map { |pr| pr.permission.permission_type.name }
  expect(types).to include(permission)
end

Then(/^it should have a permission request for "([^"]*)" access$/) do |permission_type|
  expect(@access_request.permission_requests.first.permission.permission_type.name).to eq(permission_type)
end

Then(/^it should be for "([^"]*)"$/) do |resource_name|
  expect(@access_request.resource).to eq(Resource.find_by!(name: resource_name))
end

# The approval radio buttons are named
# access_request[<attributes>][<permission_request id>][approved].
Then(/^I "([^"]*)" "([^"]*)" for "([^"]*)"$/) do |action, radio_base, _permission|
  value = action == 'approve' ? 'true' : 'false'
  id = @request.permission_requests.first.id
  choose("#{radio_base}_#{id}_approved_#{value}")
end

Then(/^I "([^"]*)" "([^"]*)" "([^"]*)" permission for "([^"]*)"$/) do |action, radio_base, _permission, request|
  @request = requests(request.to_sym)
  value = action == 'approve' ? 'true' : 'false'
  id = @request.permission_requests.first.id
  choose("#{radio_base}_#{id}_approved_#{value}")
end

Given(/^I am an owner of "([^"]*)"$/) do |resource|
  expect(resources(resource.to_sym).users).to include(@current_user)
end

Given(/^"([^"]*)" is owned by "([^"]*)"$/) do |resource, login|
  @user = User.find_by!(login: login)
  expect(resources(resource.to_sym).users).to include(@user)
end

Given(/^it is waiting for resource owner assignment$/) do
  expect(@access_request.reload).to be_waiting_for_resource_owner_assignment
end

Given(/^it is waiting for resource owner$/) do
  expect(@access_request.reload).to be_waiting_for_resource_owner
end

Then(/^"([^"]*)" access requests should be "([^"]*)"$/) do |request, current_state|
  @request = requests(request.to_sym)
  expect(@request.access_requests.reload.map(&:current_state).uniq).to eq([current_state])
end

Then(/^the requests access requests should be "([^"]*)"$/) do |state|
  @request.reload
  expect(@request.access_requests.reload.map(&:current_state).uniq).to eq([state])
end

Then(/^the requests access requests should be unassigned$/) do
  @request.reload
  expect(@request.access_requests.reload.map(&:current_worker).compact).to be_empty
end

Then(/^the access request should be assigned to "([^"]*)"$/) do |login|
  expect(@access_request.reload.current_worker.login).to eq(login)
end

Then(/^the access request resource owner should be "([^"]*)"$/) do |login|
  expect(@access_request.reload.resource_owner.login).to eq(login)
end

Then(/^"([^"]*)" should have "([^"]*)" permissions$/) do |login, permission|
  user = User.find_by!(login: login)
  expect(user.reload.permissions).to include(permissions(permission.to_sym))
end

Then(/^a access request to revoke "([^"]*)" access to "([^"]*)" should be created$/) do |permission, resource|
  @resource = resources(resource.to_sym)
  @access_request = AccessRequest.order(:id).last
  expect(@access_request.resource).to eq(@resource)
  expect(@access_request.permission_requests.first.permission.permission_type.name).to eq(permission)
end

Then(/^the access request should be for "([^"]*)"$/) do |login|
  expect(@access_request.user.login).to eq(login)
end

Given(/^"([^"]*)" has "([^"]*)" permission$/) do |login, permission|
  @user = User.find_by!(login: login)
  @permission = permissions(permission.to_sym)
  @user.permissions << @permission unless @user.permissions.include?(@permission)
  expect(@user.reload.permissions).to include(@permission)
end

Then(/^"([^"]*)" should not have "([^"]*)" permission$/) do |login, permission|
  user = User.find_by!(login: login)
  expect(user.reload.permissions).not_to include(permissions(permission.to_sym))
end
