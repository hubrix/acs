require 'rails_helper'

RSpec.describe Request do
  describe 'the state machine' do
    it 'starts pending' do
      expect(described_class.new.current_state).to eq('pending')
    end

    it 'stamps completed_at when it completes' do
      request = requests(:rcooper_wiki_help_desk)
      request.complete!
      expect(request.reload.completed_at).to be_present
    end

    it 'sends standard requests to the manager on start' do
      request = described_class.create!(
        user: users(:dengle), created_by: users(:dengle), reason: described_class::REASONS[:standard]
      )
      request.access_requests.create!(
        resource: resources(:jira),
        request_action: AccessRequest::ACTIONS[:grant],
        permission_ids: [permissions(:jira).id]
      )
      request.start!
      expect(request.access_requests.reload.map(&:current_state)).to all(eq('waiting_for_manager'))
    end

    it 'sends non-standard requests straight to the help desk' do
      request = described_class.create!(
        user: users(:dengle), created_by: users(:nott), reason: described_class::REASONS[:new_hire]
      )
      request.access_requests.create!(
        resource: resources(:jira),
        request_action: AccessRequest::ACTIONS[:grant],
        permission_ids: [permissions(:jira).id]
      )
      request.start!
      expect(request.access_requests.reload.map(&:current_state))
        .to all(eq('waiting_for_help_desk_assignment'))
    end

    it 'orders its access requests by resource name on start' do
      request = described_class.create!(
        user: users(:dengle), created_by: users(:nott), reason: described_class::REASONS[:new_hire]
      )
      %i[jira cyberark].each do |name|
        request.access_requests.create!(
          resource: resources(name),
          request_action: AccessRequest::ACTIONS[:grant],
          permission_ids: [permissions(:"#{name}_admin").id]
        )
      end
      request.start!
      ordered = request.access_requests.reload.map { |ar| ar.resource.name }
      expect(ordered).to eq(ordered.sort)
      expect(request.access_requests.map(&:position)).to eq([1, 2])
    end
  end

  describe '#percent_complete' do
    it 'is 100 for a completed request' do
      expect(requests(:dengle_jira_admin_complete).percent_complete).to eq(100)
    end

    it 'counts three steps for a standard self-service request' do
      # dengle_us_portal is with the manager: 0 of 3 steps done.
      expect(requests(:dengle_us_portal).percent_complete).to eq(0)
    end

    it 'counts progress once the request reaches the help desk' do
      # dengle_wiki_help_desk has cleared the manager and the resource owner.
      expect(requests(:dengle_wiki_help_desk).percent_complete).to eq(67)
    end
  end

  describe 'scopes' do
    it 'finds in-progress requests' do
      expect(described_class.not_completed).to include(requests(:dengle_us_portal))
      expect(described_class.not_completed).not_to include(requests(:dengle_jira_admin_complete))
    end

    it 'finds requests for a user and everyone below them' do
      results = described_class.for_user_and_descendants(users(:rcooper))
      expect(results).to include(requests(:rcooper_wiki_help_desk), requests(:dengle_us_portal))
    end

    it 'finds requests currently assigned to a user' do
      expect(described_class.current_worker(users(:rcooper))).to include(requests(:dengle_us_portal))
    end

    it 'finds requests touching resources a user owns' do
      expect(described_class.for_resources_user_owns(users(:mgroulx)))
        .to include(requests(:dengle_wiki_help_desk))
    end

    it 'filters by the state of the child access requests' do
      expect(described_class.with_access_requests_state('waiting_for_manager'))
        .to include(requests(:dengle_us_portal))
    end

    it 'finds unassigned help desk work' do
      expect(described_class.unassigned_help_desk_requests)
        .to include(requests(:dengle_wiki_help_desk))
    end

    it 'finds everything sitting at the help desk' do
      expect(described_class.at_help_desk)
        .to include(requests(:dengle_wiki_help_desk), requests(:rcooper_wiki_help_desk))
    end

    it 'separates terminations' do
      expect(described_class.are_terminations)
        .to eq([requests(:holajuwon_wiki_waiting_for_help_desk_assignment)])
      expect(described_class.without_terminations)
        .not_to include(requests(:holajuwon_wiki_waiting_for_help_desk_assignment))
    end

    it 'finds requests a user is involved in' do
      expect(described_class.involved_user(users(:mstreet).id))
        .to include(requests(:rcooper_wiki_help_desk))
    end

    it 'combines the dashboard scopes without raising' do
      expect do
        described_class.with_extra_info.not_completed.current_worker(users(:rcooper)).by_importance.to_a
      end.not_to raise_error
    end
  end

  describe '#goes_directly_to_help_desk?' do
    it 'is false for standard requests' do
      expect(requests(:dengle_us_portal).goes_directly_to_help_desk?).to be(false)
    end

    it 'is true for every other reason' do
      expect(requests(:holajuwon_wiki_waiting_for_help_desk_assignment).goes_directly_to_help_desk?)
        .to be(true)
    end
  end

  describe '#created_by_manager_for_subordinate?' do
    it 'is true when a manager files on behalf of a report' do
      expect(requests(:dengle_revoke_acunote_help_desk).created_by_manager_for_subordinate?).to be(true)
    end

    it 'is false for a self-service request' do
      expect(requests(:dengle_us_portal).created_by_manager_for_subordinate?).to be(false)
    end
  end
end
