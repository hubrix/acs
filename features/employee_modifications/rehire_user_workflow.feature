Feature: rehire a user
  As a hr member
  I want to rehire a user
  So that they can do their job

  Scenario: hr rehires employee
    Given I am logged in as "nott"
    And I follow "Terminated Users"
    And I follow the link to user "egarret"
    And I press "Rehire Emily Garret"
    Then the user "egarret" should be "active"
    And "egarret" should have a request with 2 access requests created for them
    And the request reason should be "rehire"
    And the request should be created by "nott"
    And the requests access requests should request to "grant"    
    And the requests access requests should be "waiting_for_help_desk_assignment"
    And I should see "Successfully rehired user and notified help desk"
    And I should be on the user page for "egarret"
    
  Scenario: hr rehires employee with existing termination requests 
    Given I am logged in as "nott"
    And I follow "Terminated Users"
    And I follow the link to user "holajuwon"
    And I press "Rehire Hakeem Olajuwon"
    Then I should be on the user page for "holajuwon"
    And I should see "Termination requests must be completed before the user is rehired"

