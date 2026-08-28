@now
Feature: employee requests additional access request
  As an employee
  I want to request access
  So that I or my subordinate can access a resource

  Scenario: request access
    Given I am logged in as "dengle"
    And I do not have any access to the resource "Cyberark" from resource group "application_access"
    When I go to the new access request page
    And I check "Cyberark"
    And press "Next Step"
		And I check "admin"
    And I fill in "access_request_0_notes_attributes_body" with "yes please"
    And I press "Request Access"
    Then "dengle" should have a request with 1 access requests created for them
    And the request reason should be "standard"
    And the requests access requests should be "waiting_for_manager"
    And the requests access requests should be assigned to "rcooper"
    And the access request for "cyberark" should request "admin" access
		And I should see "Access request has been sent to your manager."

  Scenario: request access to a resource that you already have a pending access request for
    Given I am logged in as "dengle"
    And I have a pending access request for "US Portal" from resource group "portal_access"
    When I go to the new access request page
    And I check "US Portal"
    And I press "Next Step"
    Then the checkbox for "us_portal_admin" should be disabled
    And the checkbox for "us_portal_executive" should be disabled

  Scenario: request access for a subordinate
    Given I am logged in as "rcooper"
    And "dengle" is my subordinate
    When I go to the new access request page
    And I select "dengle" from "user_id"
    And I check "Cyberark"
    And I press "Next Step"
    And I check "admin"
    And I fill in "access_request_0_notes_attributes_body" with "its useful"
    And I press "Request Access"
    Then "dengle" should have a request with 1 access requests created for them
    And the request reason should be "standard"
    And the request state should be "in_progress"
    And the requests access requests should be "waiting_for_resource_owner"
    And the access request for "cyberark" should request "admin" access
    And I should see "Resource owners have been notified about your access request"

