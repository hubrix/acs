Feature: change user permissions
  As an employee or manager
  I want to change my permissions
  
  Scenario: employee sets items per page
    Given I am logged in as "dengle"
		When I go to the preferences page
		And I select "40" from "preferences_preferred_items_per_page"
    And I press "Save"
    Then I should be on the preferences page
    And I should see "Preferences updated"
    And I should not see "Viewable departments during user creation:"
    And "dengle" should have "40" preferred items per page
    
  Scenario: manager sets viewable jobs  
    Given I am logged in as "mgroulx"
		When I go to the preferences page
    And I select "IT Administration" from "preferences_preferred_viewable_departments"
    And I press "Save"
    Then I should be on the preferences page
    And I should see "Preferences updated"
    And "mgroulx" should have "IT Administration" selected as the viewable department
