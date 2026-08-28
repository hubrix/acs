module NavigationHelpers
  # Maps a page name used in a feature onto a path.
  def path_to(page_name)
    case page_name
    when /the home\s?page/, /the login page/
      '/'
    # /login and / both render the sign-in form; refusals redirect to /login.
    when /the login form/
      login_path
    when /the new access request page/
      new_access_request_path
    when /the new permissions page/
      new_permissions_access_requests_path
    when /the new user page/
      new_admin_user_path
    when /the admin users page/
      admin_users_path
    when /the admin users edit page for "([^"]*)"/
      edit_admin_user_path(User.find(fixture(Regexp.last_match(1))))
    when /the show request page for "([^"]*)"$/
      request_path(Request.find(fixture(Regexp.last_match(1))))
    when /the show access request page for "([^"]*)"$/
      access_request_path(AccessRequest.find(fixture(Regexp.last_match(1))))
    when /the manager approval page for "([^"]*)"/
      manager_approval_access_request_path(AccessRequest.find(fixture(Regexp.last_match(1))))
    when /the resource owner approval page for "([^"]*)"/
      resource_owner_approval_access_request_path(AccessRequest.find(fixture(Regexp.last_match(1))))
    when /the revoke access request page/
      revoke_access_requests_path
    when /the user page for "([^"]*)"/
      user_path(User.find_by!(login: Regexp.last_match(1)))
    when /the transfer page for "([^"]*)"/
      # The id travels in the form body, not the query string.
      transfer_new_path
    when /the dashboard page/
      dashboard_path
    when /the preferences page/
      preferences_path
    when /the search page/
      search_path
    else
      begin
        page_name =~ /the (.*) page/
        send(Regexp.last_match(1).split(/\s+/).push('path').join('_').to_sym)
      rescue StandardError
        raise "Can't find mapping from \"#{page_name}\" to a path.\n" \
              "Now, go and add a mapping in #{__FILE__}"
      end
    end
  end
end

World(NavigationHelpers)
World(Rails.application.routes.url_helpers)
