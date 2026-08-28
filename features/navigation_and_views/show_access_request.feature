Feature: viewing access requests
  As a user
  I want to be able to login
  So I can view access requests

  Scenario: view a completed access request
    Given I am logged in as "dengle"
    When I visit the show access request page for "dengle_jira_admin_complete"
    Then I should see "Request Action: Grant"
    And I should see "Resource: Jira (Application Access)"
    And I should see "Current Status: Completed"
    And I should see "Dan Engle requested admin for themself be granted."
    And I should see "Roland Cooper approved admin"
    And I should see "Marc Groulx approved admin"
    And I should see "Marvin Street processed admin"

  Scenario: view a access request that is waiting for manager
    Given I am logged in as "dengle"
    When I visit the show access request page for "dengle_us_portal"
    Then I should see "Request Action: Grant"
    And I should see "Resource: US Portal (Portal Access)"
    And I should see "Current Status: Waiting for manager"
    And I should see "Dan Engle requested admin for themself be granted."
    And I should see "Roland Cooper is reviewing this request."
    # And I should see "This request is waiting for manager review."
    And I should see "Waiting for previous steps."

  Scenario: view a access request that is for a new user and waiting for help desk assignment
    Given I am logged in as "dengle"
    When I visit the show access request page for "jfaceless_wiki_waiting_for_help_desk_assignment"
    Then I should see "New Employee Request! Start Date:"
    And I should see "Request Action: Grant"
    And I should see "Resource: Wiki (Application Access)"
    And I should see "Current Status: Waiting for help desk assignment"
    And I should see "Nadine Ott requested access for Jane Faceless be granted."
    And I should see "This step is skipped because the access request is for a new_hire."
    And I should see "This step is skipped because the access request is for a new_hire."
    And I should see "This request is waiting for help desk assignment."

  Scenario: view a canceled access request
    Given I am logged in as "dengle"
    When I visit the show access request page for "egarret_wiki_canceled"
    Then I should see "Request Action: Grant"
    And I should see "Resource: Wiki (Application Access)"
    And I should see "Current Status: Canceled"
    And I should see "Emily Garret requested access for themself be granted."
    And I should see "Olga Dolchenko approved access"
    And I should see "Resource Owner Review This access request has been canceled."
    And I should see "Help Desk Progress This access request has been canceled."
    