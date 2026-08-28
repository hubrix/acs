Feature: signing in through an identity provider
  As an employee
  I want to sign in with my work Google account
  So that I do not need a separate ACS password

  Scenario: the login page offers every configured backend
    Given I am not logged in
    When I go to the login page
    Then I should see "Sign in with Google"
    And I should see "Sign in with Single sign-on"
    And I should see "or sign in with your password"

  Scenario: signing in with Google
    Given I am not logged in
    And Google will authenticate "dengle@example.com"
    When I go to the login page
    And I press "Sign in with Google"
    Then I should be on the dashboard page
    And I should see "Signed in with Google"
    And "dengle" should have a linked "google_workspace" account

  Scenario: an employee who has already signed in with Google keeps the same link
    Given I am not logged in
    And "dengle" has a linked "google_workspace" account with uid "google-uid-1"
    And Google will authenticate "dengle@example.com" with uid "google-uid-1"
    When I go to the login page
    And I press "Sign in with Google"
    Then I should be on the dashboard page
    And "dengle" should have 1 linked account

  Scenario: an address that is not an ACS employee is turned away
    Given I am not logged in
    And Google will authenticate "stranger@example.com"
    When I go to the login page
    And I press "Sign in with Google"
    Then I should be on the login form
    And I should see "That account is not set up in ACS"

  Scenario: a terminated employee is turned away
    Given I am not logged in
    And Google will authenticate "egarret@example.com"
    When I go to the login page
    And I press "Sign in with Google"
    Then I should be on the login form
    And I should see "That employee record has been terminated"

  Scenario: the provider reports a failure
    Given I am not logged in
    And Google will fail with "access_denied"
    When I go to the login page
    And I press "Sign in with Google"
    Then I should be on the login form
    And I should see "Sign-in was not completed"

  Scenario: signing in through the generic OpenID Connect backend
    Given I am not logged in
    And the OpenID Connect provider will authenticate "rcooper@example.com"
    When I go to the login page
    And I press "Sign in with Single sign-on"
    Then I should be on the dashboard page
    And "rcooper" should have a linked "openid_connect" account
