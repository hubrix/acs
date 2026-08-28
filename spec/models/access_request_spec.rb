require 'rails_helper'

RSpec.describe AccessRequest do
  describe 'a new access request' do
    subject(:access_request) { described_class.new }

    before { access_request.valid? }

    it 'is pending' do
      expect(access_request.current_state).to eq('pending')
    end

    it 'does not require a permission request while pending' do
      expect(access_request.errors[:base])
        .not_to include('An Access Request requires at least one permission request')
    end

    it 'wants a resource' do
      expect(access_request.errors[:base]).to include('An Access Request needs to be for a resource')
    end

    it 'wants to grant or revoke' do
      expect(access_request.errors[:base]).to include('An Access Request must grant or deny access')
    end
  end

  describe 'validation against the request it belongs to' do
    let(:request) do
      Request.create!(user: users(:dengle), created_by: users(:dengle), reason: Request::REASONS[:standard])
    end

    it 'rejects a resource with no owners' do
      resources(:wiki).users.clear
      access_request = request.access_requests.build(
        resource: resources(:wiki), request_action: described_class::ACTIONS[:grant]
      )
      access_request.valid?
      expect(access_request.errors[:base]).to include("Can't request access to resource with no owners")
    end

    it 'rejects a second open request for the same permission' do
      # dengle already has an open request for us_portal_admin (fixture
      # dengle_us_portal, still waiting_for_manager).
      access_request = request.access_requests.build(
        resource: resources(:us_portal),
        request_action: described_class::ACTIONS[:grant],
        permission_ids: [permissions(:us_portal_admin).id]
      )
      access_request.valid?
      expect(access_request.errors[:base])
        .to include('An employee can not have two Access Requests for the same permission open at the same time')
    end

    it 'accepts a request for a permission with no open duplicate' do
      # dengle's only jira request (dengle_jira_admin_complete) is finished.
      access_request = request.access_requests.build(
        resource: resources(:jira),
        request_action: described_class::ACTIONS[:grant],
        permission_ids: [permissions(:jira).id]
      )
      expect(access_request).to be_valid
    end

    it 'refuses to let the current worker process their own request' do
      access_request = access_requests(:rcooper_wiki_help_desk)
      access_request.current_worker = access_request.request.user
      access_request.valid?
      expect(access_request.errors[:base]).to include("You can't process an Access Request that is for you")
    end
  end

  describe 'the state machine' do
    it 'declares the HR states the events transition into' do
      expect(described_class.aasm.states.map(&:name))
        .to include(:waiting_for_hr, :waiting_for_hr_assignment)
    end

    it 'assigns the requester\'s manager when moving to waiting_for_manager' do
      access_request = access_requests(:jserrano_wiki_waiting_for_manager)
      access_request.update_column(:current_state, 'pending')
      access_request.reload.assign_to_manager!
      expect(access_request.reload.current_state).to eq('waiting_for_manager')
      expect(access_request.manager).to eq(users(:jserrano).manager)
      expect(access_request.current_worker).to eq(users(:jserrano).manager)
    end

    it 'unassigns the current worker when it lands back in the help desk queue' do
      access_request = access_requests(:dengle_uk_portal_resource_owner)
      access_request.send_to_help_desk!
      expect(access_request.reload.current_state).to eq('waiting_for_help_desk_assignment')
      expect(access_request.current_worker).to be_nil
    end

    it 'stamps completed_at and completed_by on completion' do
      access_request = access_requests(:rcooper_wiki_help_desk)
      access_request.update_column(:current_worker_id, users(:mstreet).id)
      access_request.reload.complete!
      expect(access_request.reload).to be_completed
      expect(access_request.completed_at).to be_present
      expect(access_request.completed_by).to eq(users(:mstreet))
    end

    it 'stamps completed_at on denial too' do
      access_request = access_requests(:dengle_us_portal)
      access_request.deny!
      expect(access_request.reload).to be_denied
      expect(access_request.completed_at).to be_present
    end

    it 'reports an invalid transition through aasm_event_failed' do
      access_request = access_requests(:dengle_jira_admin_complete)
      expect { access_request.complete! }
        .to raise_error(RuntimeError, /failed to transition on event, complete!/)
    end
  end

  describe 'the workflow side effects that used to live in AccessRequestObserver' do
    it 'notifies resource owners when a request needs owner assignment' do
      access_request = access_requests(:dengle_us_portal)
      access_request.permission_requests.each { |pr| pr.update!(approved_by_manager: true) }
      expect { access_request.reload.send_to_resource_owners! }
        .to change { ActionMailer::Base.deliveries.size }.by(resources(:us_portal).users.count)
    end

    it 'notifies the assigned resource owner when the resource has a single owner' do
      access_request = access_requests(:rcooper_acunote_admin)
      access_request.resource_owner = users(:mgroulx)
      expect { access_request.assign_to_resource_owner! }
        .to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it 'emails the requester when a request is denied' do
      access_request = access_requests(:dengle_us_portal)
      access_request.deny!
      denial = ActionMailer::Base.deliveries.find do |mail|
        mail.subject.start_with?('Your request for access to')
      end
      expect(denial.to).to eq([users(:dengle).email])
    end

    it 'grants the approved permissions to the user on completion' do
      access_request = access_requests(:rcooper_wiki_help_desk)
      expect { access_request.complete! }
        .to change { users(:rcooper).reload.permissions.include?(permissions(:wiki_admin)) }
        .from(false).to(true)
    end

    it 'removes permissions on completion of a revocation' do
      users(:dengle).permissions << permissions(:acunote_admin)
      access_request = access_requests(:dengle_revoke_acunote_help_desk)
      access_request.assign_to(users(:mstreet))
      access_request.reload.complete!
      expect(users(:dengle).reload.permissions).not_to include(permissions(:acunote_admin))
    end

    it 'completes the parent request once every access request is finished' do
      access_request = access_requests(:rcooper_wiki_help_desk)
      expect { access_request.complete! }
        .to change { access_request.request.reload.current_state }
        .from('in_progress').to('completed')
    end
  end

  describe 'scopes' do
    it 'finds requests that are not finished' do
      expect(described_class.not_completed).to include(access_requests(:dengle_us_portal))
      expect(described_class.not_completed).not_to include(access_requests(:dengle_jira_admin_complete))
    end

    it 'reaches user_id through the parent request' do
      expect(described_class.for_user(users(:dengle).id))
        .to include(access_requests(:dengle_us_portal))
      expect(described_class.for_user(users(:dengle).id))
        .not_to include(access_requests(:rcooper_wiki_help_desk))
    end

    it 'excludes a given user through the parent request' do
      expect(described_class.not_for_user(users(:dengle)))
        .not_to include(access_requests(:dengle_us_portal))
    end

    it 'reaches reason through the parent request' do
      expect(described_class.are_terminations)
        .to include(access_requests(:holajuwon_wiki_waiting_for_help_desk_assignment))
      expect(described_class.without_terminations)
        .not_to include(access_requests(:holajuwon_wiki_waiting_for_help_desk_assignment))
    end

    it 'finds requests a user is involved in, in any capacity' do
      results = described_class.involved_user(users(:mstreet).id)
      expect(results).to include(access_requests(:rcooper_wiki_help_desk))
    end

    it 'finds requests for resources a user owns' do
      expect(described_class.for_resources_user_owns(users(:mgroulx)))
        .to include(access_requests(:dengle_wiki_help_desk))
    end

    it 'excludes a specific record' do
      target = access_requests(:dengle_us_portal)
      expect(described_class.but_not(target)).not_to include(target)
    end

    it 'returns everything when excluding an unsaved record' do
      expect(described_class.but_not(described_class.new).count).to eq(described_class.count)
    end

    it 'orders by importance across the join to requests' do
      expect { described_class.by_importance.to_a }.not_to raise_error
    end

    it 'eager loads the parent request user without blowing up' do
      expect { described_class.with_extra_info.to_a }.not_to raise_error
    end
  end

  describe 'authorisation' do
    it 'lets the requester cancel their own request' do
      expect(access_requests(:dengle_us_portal).can_be_canceled_by?(users(:dengle))).to be(true)
    end

    it 'lets a manager in the chain cancel a request' do
      expect(access_requests(:dengle_us_portal).can_be_canceled_by?(users(:rcooper))).to be(true)
    end

    it 'does not let an unrelated user cancel a request' do
      expect(access_requests(:dengle_us_portal).can_be_canceled_by?(users(:alee))).to be(false)
    end

    it 'does not let a finished request be cancelled' do
      expect(access_requests(:dengle_jira_admin_complete).can_be_canceled_by?(users(:dengle))).to be(false)
    end

    it 'lets a help desk member claim an unassigned help desk request' do
      access_request = access_requests(:dengle_wiki_help_desk)
      expect(access_request.can_be_assigned_to?(users(:mstreet))).to be(true)
    end

    it 'does not let a user claim their own request' do
      access_request = access_requests(:jfaceless_wiki_waiting_for_help_desk_assignment)
      expect(access_request.can_be_assigned_to?(users(:jfaceless))).to be(false)
    end
  end

  describe '#assign_to' do
    it 'assigns a resource owner and advances the state' do
      access_request = access_requests(:rcooper_acunote_admin)
      access_request.assign_to(users(:mgroulx))
      expect(access_request.reload.current_state).to eq('waiting_for_resource_owner')
      expect(access_request.resource_owner).to eq(users(:mgroulx))
      expect(access_request.current_worker).to eq(users(:mgroulx))
    end

    it 'assigns a help desk member and advances the state' do
      access_request = access_requests(:dengle_wiki_help_desk)
      access_request.assign_to(users(:mstreet))
      expect(access_request.reload.current_state).to eq('waiting_for_help_desk')
      expect(access_request.help_desk).to eq(users(:mstreet))
    end
  end

  describe 'delegation to the parent request' do
    it 'delegates user' do
      expect(access_requests(:dengle_us_portal).user).to eq(users(:dengle))
    end

    it 'delegates reason' do
      expect(access_requests(:dengle_revoke_acunote_help_desk).reason).to eq('revoke')
    end
  end
end
