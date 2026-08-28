Feature: logging in
  As a user
  I want to be able to login
  So I can modify access

  Scenario: Log in to url
    Given I am not logged in
    When I visit the show access request page for "dengle_revoke_acunote_help_desk"
    Then I should be on the login page
    And I login as "mstreet"
    And I should be on the show access request page for "dengle_revoke_acunote_help_desk"
    
  Scenario: logged in as public user and manager
    Given I am logged in as "timothyho"
    And I have the role "public"
    And I am a manager
    Then I should see "Search"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should see "New User"
    And I should not see "Requests at Help Desk"
    And I should not see "Admin"
    
  Scenario: logged in as public user and not a manager
    Given I am logged in as "alee"
    And I have the role "public"
    And I am not a manager
    Then I should see "Search"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should not see "New User"
    And I should not see "Requests at Help Desk"
    And I should not see "Admin"
    
  Scenario: logged in as an hr user
    Given I am logged in as "nott"
    And I have the role "hr"
    Then I should see "Search"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should see "New User"
    And I should see "CSV Import"
    And I should not see "Admin"
    And I should see "Users"
    And I should not see "Requests at Help Desk"
    And I should not see "Locations"
    And I should see "Departments"
    And I should not see "Resource Groups"
    
  Scenario: logged in as an help_desk user
    Given I am logged in as "jserrano"
    And I have the role "help_desk"
    And I am not a manager
    Then I should see "Search Employees"
    And I should see "Terminated Users"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should see "Requests at Help Desk"
    And I should not see "Locations"
    And I should see "Departments"
    And I should not see "Resource Groups"
    And I should not see "New User"
    And I should not see "CSV Import"
    And I should not see "Admin"
    

  Scenario: logged in as an help_desk user and manager
    Given I am logged in as "rhook"
    And I have the role "help_desk"
    And I am a manager
    Then I should see "Search"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should see "Requests at Help Desk"
    And I should not see "Locations"
    And I should see "Departments"
    And I should not see "Resource Groups"
    And I should see "New User"
    And I should see "CSV Import"
    And I should not see "Admin"
    
  Scenario: logged in as an help_desk user, manager, and admin
    Given I am logged in as "mstreet"
    And I have the role "help_desk"
    And I am a manager
    Then I should see "Search"
    And I should see "Request Access"
    And I should see "My Requests"
    And I should see "Requests at Help Desk"
    And I should see "Locations"
    And I should see "Departments"
    And I should see "Resource Groups"
    And I should see "New User"
    And I should see "CSV Import"
    And I should see "Admin"
    And I should see "Users"
    
