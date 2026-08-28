Feature: transer a user
  As a manager
  I want to transfer a subordinate
  So they have a new job

  Scenario: manager transfers subordinate
    Given I am logged in as "rcooper"
    And "dengle" is my subordinate
    When I go to the user page for "dengle"
    And I press "Transfer Dan Engle"
    Then I should be on the transfer page for "dengle"
# This test is incomplete until i can figure out how to select new values in the Job and Manager fields
#    And I unselect "rcooper" from "user_manager_id"
#    And show me the page
#    And I choose "mgroulx" from "user_manager_id"
#    And I unselect "Ops Support Engineer US" from "user_job_id"
#    And I select "Product Management Associate" from "user_job_id"
#    And show me the page
#    And I press "Complete Transfer"
#    Then I should be on the user page for "dengle"
#    And they should have the job "product_mgmt_associate"
#    And they should have the manager "mgroulx"
#    And show me the page

