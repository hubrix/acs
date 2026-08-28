module UsersHelper

  def import_result(result)
    if result.is_a?(User)
      "#{result.first_name} #{result.last_name} successfully imported!"
    elsif result.is_a?(String)
      "#{result}"
    else
      result.inspect
    end
  end

  def import_access(result)
    if result.is_a?(User)
      unless result.permissions.empty?
        perms = String.new
        result.permissions.each { |permission|
        perms+"<tr><td><%=h permission.resource.resource_group.name%></td><td><%=h permission.resource.name %></td><td><%=h permission.permission_type.name %></td></tr>"
         }
        return perms.to_s
      else
        "No User Permissions Set!"
      end
    end
  end

  def submitted_by(user)
    user.submitted_by.nil? ? "System user" : user.submitted_by.full_name
  end
  
  # TODO correct this. it's only here now because in dev mode, some termed users don't have that field set (and lazyness)
  def terminated_by(user)
    user.terminated_by.nil? ? 'System user' : user.terminated_by.full_name
  end
end

