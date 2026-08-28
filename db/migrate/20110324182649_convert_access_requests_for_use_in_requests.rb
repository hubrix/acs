# README
# depending on you are running this migrations, you made need to make some quick
# reverts to the access_request model.
#         ADD: belongs_to :user
# COMMENT OUT: delegate :user, :to => :request
# COMMENT OUT: delegate :reason, :to => :request
# user.rb
#      MODIFY: has_many :access_requests TO COMMENT OUT ->, :through => :requests
# try running the migrations first, before making the edits to access_request.rb
class ConvertAccessRequestsForUseInRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :request_id, :integer
    add_index :access_requests, :request_id
    AccessRequest.reset_column_information
    User.includes(:access_requests).all.each do |user|
      ['new_hire', 'termination'].each do |reason|
        old_requests = user.access_requests.where(:reason => reason).all
        unless old_requests.blank?
          request = Request.create(
            :reason => reason,
            :user_id => user.id,
            :created_by_id => old_requests.first.created_by_id,
            :current_state => old_requests.all?{|a| a.finished? } ? 'completed' : 'in_progress'
          )
          request.update_attribute(:created_at, old_requests.first.created_at)
          request.access_requests << old_requests
        end
      end
      user.access_requests.where('reason not in (?)', %w{new_hire termination}).all.each do |access_request|        
        request = Request.create(
          :reason => access_request.reason,
          :user_id => user.id,
          :created_by_id => access_request.created_by_id,
          :current_state => access_request.finished? ? 'completed' : 'in_progress'
        )
        request.update_attribute(:created_at, access_request.created_at)
        access_request.update_attribute(:request_id, request.id)
      end
    end    
    remove_column :access_requests, :created_by_id
    remove_column :access_requests, :user_id
    remove_column :access_requests, :for_new_user
    remove_column :access_requests, :reason
  end

  def self.down
  end
end
