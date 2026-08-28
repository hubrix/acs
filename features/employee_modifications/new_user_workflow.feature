Feature: hr or manager creates a new employee
  As a hr member or manager
  I want to create a new user
  So that they can do their job

  Scenario: hr creates new user
    Given I am logged in as "nott"
    And I have the role "hr"
	  When I go to the new user page
	  And I select "Administrative Assistant" from "user_job_id"
	  And I select "mgroulx" from "user_manager_id"
	  And I fill in "user_first_name" with "John"
	  And I fill in "user_last_name" with "Doe"
	  And I press "Next Step"
	  And I use the default permissions for "administrative_assistant"
	  And I press "Create User"
	  Then "jdoe" should be created
    And they should have the job "administrative_assistant"
    And they should have the manager "mgroulx"
    And they should have the email address "jdoe@example.com"
    And the user "jdoe" should be "active"
	  And a request for resources needed by "administrative_assistant" should be created
    And the request reason should be "new_hire"
	  And the requests access requests should be "waiting_for_help_desk_assignment"
  	And the new employee should not have any permissions
    And the new employee should have the role "public"

  Scenario: manager creates a new user
    Given I am logged in as "odolchenko"
    And I am a manager
    When I go to the new user page
    And I select "Application Support Rep" from "user_job_id"
    And I select "odolchenko" from "user_manager_id"
    And I fill in "user_first_name" with "Jane"
    And I fill in "user_last_name" with "Doe"
    And I press "Next Step"
    And I use the default permissions for "uk_application_support"
    And I press "Create User"
    Then "jdoe" should be created
    And they should have the job "uk_application_support"
    And they should have the manager "odolchenko"
    And they should have the email address "jdoe@example.com"
    And the user "jdoe" should be "pending"
    And the user should have 0 access requests

  Scenario: hr approve manager created user
    Given I am logged in as "nott"
    And I have the role "hr"
    And I follow "That Guy"
    When I press "Confirm Employee"
    Then "tguy" should be activated
    And "tguy" should have a request with 2 access requests created for them
    And the requests access requests should be "waiting_for_help_desk_assignment"
    And the requests access requests should have "nott" for "hr" assignment
    And the request reason should be "new_hire"
    And the request should be by manager for subordinate
    And I should be on the user page for "tguy"
    
