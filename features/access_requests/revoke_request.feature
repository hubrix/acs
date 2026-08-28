Feature: revoke access to a permission
  As a manager
  I want to revoke some access
  So that my subordinate no longer can access a particular permission

  Scenario: manager creates revoke request
    Given I am logged in as "rcooper"
		And "dengle" is my subordinate
		When I go to the revoke access request page
    And I choose "Dan Engle"
    And I press "Next Step"
    And I check permission "jira_admin"
    And I press "Submit Request"
    Then a access request to revoke "admin" access to "jira" should be created
    Then "dengle" should have a request with 1 access requests created for them
    And the requests access requests should be "waiting_for_help_desk_assignment"
    And the request reason should be "revoke"
		
  Scenario: manager forgets to select a permission
    Given I am logged in as "rcooper"
		And "dengle" is my subordinate
		When I go to the revoke access request page
    And I choose "Dan Engle"
    And I press "Next Step"
    And I press "Submit Request"
    Then I should see "You need to select at least one permission to revoke."