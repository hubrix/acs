# Generic browser interaction steps.
#
# cucumber-rails stopped shipping web_steps.rb in 1.0, so these are the
# equivalents written directly against Capybara instead of webrat.

When(/^(?:|I )go to (.+)$/) do |page_name|
  visit path_to(page_name)
end

Given(/^(?:|I )am on (.+)$/) do |page_name|
  visit path_to(page_name)
end

When(/^(?:|I )press "([^"]*)"$/) do |button|
  click_button(button)
end

When(/^(?:|I )follow "([^"]*)"$/) do |link|
  click_link(link)
end

When(/^(?:|I )fill in "([^"]*)" with "([^"]*)"$/) do |field, value|
  fill_in(field, with: value)
end

When(/^(?:|I )select "([^"]*)" from "([^"]*)"$/) do |value, field|
  select(value, from: field)
end

When(/^(?:|I )unselect "([^"]*)" from "([^"]*)"$/) do |value, field|
  unselect(value, from: field)
end

When(/^(?:|I )check "([^"]*)"$/) do |field|
  check(field)
end

When(/^(?:|I )uncheck "([^"]*)"$/) do |field|
  uncheck(field)
end

When(/^(?:|I )choose "([^"]*)"$/) do |field|
  choose(field)
end

Then(/^(?:|I )should see "([^"]*)"$/) do |text|
  expect(page).to have_content(text)
end

Then(/^(?:|I )should not see "([^"]*)"$/) do |text|
  expect(page).to have_no_content(text)
end

Then(/^(?:|I )should be on (.+)$/) do |page_name|
  expect(current_path).to eq(path_to(page_name))
end

Then(/^the "([^"]*)" (?:field|checkbox) should be disabled$/) do |locator|
  expect(page).to have_field(locator, disabled: true)
end

Then(/^the checkbox with id "([^"]*)" should be checked$/) do |id|
  expect(page).to have_field(id, checked: true)
end

# Debugging helpers.
Then(/^show me the page$/) do
  save_and_open_page
end

Then(/^print the page$/) do
  puts page.body
end
