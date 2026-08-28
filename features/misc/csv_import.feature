Feature: CSV Import
  As an admin
  I want to import users via csv
  So they can do their job

Scenario: admin imports existing users
    Given I am logged in as "mstreet"
    And I follow "CSV Import"
    Then I should see "backfill"
    And I should see "user"
    And I should see "Upload from CSV"

