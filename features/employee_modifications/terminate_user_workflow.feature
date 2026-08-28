Feature: terminate a user
  As a manager or hr
  I want to terminate a subordinate
  So that all their access is removed

  Scenario: manager terminates subordinate
    Given I am logged in as "rcooper"
		And "dengle" is my subordinate
		When I go to the revoke access request page
    And I choose "Dan Engle"
    And I press "Next Step"
    And I press "Terminate Dan"
    Then the user "dengle" should be "suspended"
    And "dengle" should have a request with 3 access requests created for them
    And the request reason should be "termination"
    And the request should be by manager for subordinate
    And the requests access requests should request to "revoke"
    And the requests access requests should be "waiting_for_help_desk_assignment"
    And all permission requests should be approved by "manager"
    And all permission requests should not be approved by "hr"
    And all permission requests should not be approved by "resource_owner"
    And I should see "Termination request has been sent to hr for verification."
    And I should be on the user page for "dengle"

  Scenario: hr approves manager termination request
    Given I am logged in as "nott"
    And I follow "Johnny Rocket"
    When I press "Confirm Termination"
    Then the user "jrocket" should be "terminated"
    And I should see "Help desk has been notified of termination"
    And I should be on the user page for "jrocket"

  Scenario: hr denies manager termination request
    Given I am logged in as "nott"
    And I follow "Johnny Rocket"
    When I press "Deny Termination Request"
    Then the user "jrocket" should be "active"
    And there should be 0 access request for "jrocket"
    And I should see "Manager has been notified that their termination request has been denied."
    And I should be on the user page for "jrocket"

  Scenario: hr terminates employee
    Given I am logged in as "nott"
    And I follow "Search Employees"
    And I follow the link to user "dengle"
    And I press "Terminate Dan Engle"
    Then the user "dengle" should be "terminated"
    And "dengle" should have a request with 3 access requests created for them
    And the request reason should be "termination"
    And the request should be created by "nott"
    And the requests access requests should request to "revoke"
    And the requests access requests should be "waiting_for_help_desk_assignment"
    And all permission requests should not be approved by "manager"
    And all permission requests should be approved by "hr"
    And all permission requests should not be approved by "resource_owner"
    And I should see "Help desk has been notified of termination."
    And I should be on the user page for "dengle"

