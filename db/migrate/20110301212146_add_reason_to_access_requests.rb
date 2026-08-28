class AddReasonToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    ChangeLogger.whodunnit = "database_migration"
    
    add_column :access_requests, :reason, :string, :null => false, :default => 'standard'
    AccessRequest.reset_column_information
    AccessRequest.all.each do |access_request|
      case access_request.request_action
      when 'grant'
        if access_request.for_new_user?
          access_request.update_attributes(
            :reason => 'new_hire'
          )          
        else
          access_request.update_attributes(
            :reason => 'standard'
          )
        end
      when 'revoke'
        access_request.update_attributes(
          :reason => 'revoke'
        )
      when 'terminate'
        access_request.update_attributes(
          :request_action => 'revoke',
          :reason => 'termination'
        )
      when 'rehire'
        access_request.update_attributes(
          :request_action => 'grant',
          :reason => 'rehire'
        )        
      else
      end
    end
    # I'm really not sure what difference, if any, there is between these
    # We need to review queries and indexes at some point
    add_index :access_requests, [:reason, :request_action]
    add_index :access_requests, [:request_action, :reason]
    
    # TODO make this remove the for_new_user column
  end

  def self.down
    remove_column :access_requests, :reason
  end
end
