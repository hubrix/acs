Feature: transfer a user
  As a manager
  I want to transfer a subordinate
  So they have a new job

Scenario: manager transfers subordinate
    Given I am logged in as "rcooper"
    And "dengle" is subordinate to "rcooper"
    When I go to the user page for "dengle"
    And I should see "Transfer Dan Engle"
    And I press "Transfer Dan Engle"
    Then I should be on the transfer page for "dengle"
    And I select "Product Management Associate" from "user_job_id"
    And I select "mgroulx" from "user_manager_id"
    And I press "Complete Transfer"
    Then I should be on the user page for "dengle"
    And I should see "Employee transfer completed."
    And "dengle" should have the job "Product Management Associate"
    And they should have the manager "mgroulx"
