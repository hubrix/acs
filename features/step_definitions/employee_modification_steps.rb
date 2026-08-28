When(/^I use the default permissions for "([^"]*)"$/) do |job|
  @job = jobs(job.to_sym)
  @job.permissions.each do |permission|
    expect(page).to have_field("user_permission_ids_#{permission.id}", checked: true, disabled: true)
  end
end

Then(/^"([^"]*)" should be created$/) do |login|
  @user = User.find_by(login: login)
  expect(@user).to be_present
end

Then(/^they should have the job "([^"]*)"$/) do |job|
  expected = begin
    jobs(job.to_sym)
  rescue StandardError
    Job.find_by!(name: job)
  end
  expect(@user.reload.job).to eq(expected)
end

Then(/^they should have the manager "([^"]*)"$/) do |manager|
  expect(@user.reload.manager).to eq(users(manager.to_sym))
end

Then(/^they should have the email address "([^"]*)"$/) do |email|
  expect(@user.reload.email).to eq(email)
end

Then(/^a "([^"]*)" "([^"]*)" should be created with "([^"]*)" and "([^"]*)"$/) do |first_name, last_name, _job_title, manager|
  @manager = users(manager.to_sym)
  @user = User.find_by!(first_name: first_name, last_name: last_name, job_id: @job.id, manager_id: @manager.id)
  expect(@user.created_at).to be_within(5).of(Time.now)
end

Then(/^a request for resources needed by "([^"]*)" should be created$/) do |job|
  # TODO: compare the actual permissions and not the number of them
  job = jobs(job.to_sym)
  @request = @user.requests.order(:id).first
  expect(@request.permission_requests.size).to eq(job.permissions.size)
end

Then(/^it should be sent to help desk$/) do
  expect(@user.access_requests.first).to be_waiting_for_help_desk_assignment
end

Then(/^the new employee should not have any permissions$/) do
  expect(@user.reload.permissions).to be_blank
end

Then(/^the new employee should have the role "([^"]*)"$/) do |role|
  expect(@user.reload.roles).to include(roles(role.to_sym))
end

Then(/^"([^"]*)" should be activated$/) do |login|
  @user = User.find_by!(login: login).reload
  expect(@user.current_state).to eq('active')
  expect(@user.activated_at).not_to be_nil
end

Then(/^"([^"]*)" should have a request with (\d+) access requests created for them$/) do |login, number|
  @user = User.find_by!(login: login)
  @request = @user.requests.order(:id).last
  expect(@request).to be_present
  expect(@request.access_requests.size).to eq(number.to_i)
end

Then(/^the access requests should be "([^"]*)"$/) do |current_state|
  expect(@request.access_requests.reload.map(&:current_state).uniq).to eq([current_state])
end

Then(/^the requests access requests should have "([^"]*)" for "([^"]*)" assignment$/) do |login, role|
  user = users(login.to_sym)
  @request.access_requests.reload.each do |access_request|
    expect(access_request.public_send(role)).to eq(user)
  end
end

Then(/^"([^"]*)" should have "([^"]*)" preferred items per page$/) do |login, items|
  @user = User.find_by!(login: login)
  expect(@user.reload.preferred_items_per_page).to eq(items.to_i)
end

Then(/^"([^"]*)" should have "([^"]*)" selected as the viewable department$/) do |login, department_name|
  @user = User.find_by!(login: login)
  department = Department.find_by!(name: department_name)
  expect(@user.reload.viewable_departments).to eq([department.id])
end

Then(/^the access requests reason should be "([^"]*)"$/) do |reason|
  expect(@request.access_requests.reload.map(&:reason).uniq).to eq([reason])
end

Then(/^"([^"]*)" should have the job "([^"]*)"$/) do |login, job|
  @user = User.find_by!(login: login)
  expect(@user.reload.job.name).to eq(job)
end
