require 'rails_helper'

# Renders every mailer action. The Rails 3 code shipped actions whose templates
# had been renamed away underneath them (RequestMailer#notify_manager) or never
# existed at all, which only surfaced at runtime.
RSpec.describe 'mailers' do
  let(:access_request) { access_requests(:dengle_us_portal) }
  let(:request) { requests(:dengle_us_portal) }
  let(:user) { users(:dengle) }
  let(:manager) { users(:rcooper) }
  let(:hr) { users(:nott) }
  let(:help_desk) { users(:mstreet) }
  let(:resource) { resources(:wiki) }

  def expect_renderable(mail)
    expect(mail.to).to be_present
    expect(mail.from).to eq([App.email[:from]])
    expect(mail.subject).to be_present
    expect(mail.body.encoded).to be_present
    mail
  end

  describe RequestMailer do
    it 'renders request_receipt' do
      expect_renderable(described_class.request_receipt(request))
    end

    it 'renders request_complete' do
      expect_renderable(described_class.request_complete(request))
    end

    it 'renders notify_manager to the requester\'s manager' do
      mail = expect_renderable(described_class.notify_manager(request))
      expect(mail.to).to eq([manager.email])
      expect(mail.subject).to include(user.full_name)
    end

    it 'renders notify_resource_owner' do
      expect_renderable(described_class.notify_resource_owner(request, users(:mgroulx)))
    end

    it 'renders notify_help_desk' do
      expect_renderable(described_class.notify_help_desk(request, help_desk))
    end

    it 'renders notify_help_desk_of_new_user' do
      expect_renderable(described_class.notify_help_desk_of_new_user(request, help_desk))
    end

    it 'renders notify_help_desk_of_terminated_user' do
      expect_renderable(described_class.notify_help_desk_of_terminated_user(request, help_desk))
    end
  end

  describe UserMailer do
    it 'renders notify_hr_of_user_creation' do
      mail = expect_renderable(described_class.notify_hr_of_user_creation(user, hr))
      expect(mail.to).to eq([hr.email])
    end

    it 'renders notify_hr_of_user_termination_by_manager' do
      expect_renderable(described_class.notify_hr_of_user_termination_by_manager(user, hr))
    end

    it 'renders notify_manager_of_user_transfer' do
      expect_renderable(described_class.notify_manager_of_user_transfer(user, manager, hr))
    end
  end

  describe AccessRequestMailer do
    it 'renders notify_user_of_manager_approval' do
      expect_renderable(described_class.notify_user_of_manager_approval(access_request))
    end

    it 'renders request_needs_owner_assignment' do
      expect_renderable(described_class.request_needs_owner_assignment(access_request, users(:mgroulx)))
    end

    it 'renders send_access_request_receipt' do
      expect_renderable(described_class.send_access_request_receipt(access_request))
    end

    it 'renders notify_manager_of_pending_acf' do
      expect_renderable(described_class.notify_manager_of_pending_acf(access_request))
    end

    it 'renders notify_manager_of_canceled_access_request' do
      expect_renderable(described_class.notify_manager_of_canceled_access_request(access_request))
    end

    it 'renders notify_resource_owner_of_assignment' do
      assigned = access_requests(:dengle_uk_portal_resource_owner)
      expect_renderable(described_class.notify_resource_owner_of_assignment(assigned))
    end

    it 'renders request_needs_help_desk_assignment' do
      expect_renderable(described_class.request_needs_help_desk_assignment(access_request, help_desk))
    end

    it 'renders notify_user_of_completed_request' do
      completed = access_requests(:dengle_jira_admin_complete)
      expect_renderable(described_class.notify_user_of_completed_request(completed))
    end

    it 'renders notify_user_of_request_denial' do
      expect_renderable(described_class.notify_user_of_request_denial(access_request))
    end

    it 'renders remind_manager_of_pending_acf' do
      expect_renderable(described_class.remind_manager_of_pending_acf(manager, 3))
    end

    it 'renders remind_owner_of_pending_acf' do
      expect_renderable(described_class.remind_owner_of_pending_acf(users(:mgroulx), 2, [resource.name]))
    end

    it 'renders remind_hr_of_pending_acf' do
      expect_renderable(described_class.remind_hr_of_pending_acf(hr, 1))
    end

    it 'renders remind_assignee_of_incomplete_acf' do
      expect_renderable(described_class.remind_assignee_of_incomplete_acf(help_desk, 4))
    end

    it 'renders notify_1_up_manager' do
      expect_renderable(described_class.notify_1_up_manager(user, 2))
    end

    it 'renders remind_help_desk_of_unassigned_acf' do
      expect_renderable(described_class.remind_help_desk_of_unassigned_acf(help_desk, 5))
    end

    it 'renders remind_resource_owners_of_unassigned_acf' do
      expect_renderable(described_class.remind_resource_owners_of_unassigned_acf(users(:mgroulx), 1, resource))
    end
  end

  describe AccessRequests::Reminders do
    it 'sends manager reminders for stale requests' do
      AccessRequest.update_all(updated_at: 3.days.ago)
      expect { AccessRequest.remind_managers }
        .to change { ActionMailer::Base.deliveries.size }.by_at_least(1)
    end

    it 'sends resource owner reminders for stale requests' do
      AccessRequest.update_all(updated_at: 3.days.ago)
      expect { AccessRequest.remind_owners }
        .to change { ActionMailer::Base.deliveries.size }.by_at_least(1)
    end

    it 'nags the help desk about unassigned work' do
      expect { AccessRequest.annoy_helpdesk }
        .to change { ActionMailer::Base.deliveries.size }.by(User.help_desk.count)
    end

    it 'nags resource owners about unassigned work' do
      AccessRequest.update_all(updated_at: 3.days.ago)
      expect { AccessRequest.annoy_resource_owners }
        .to change { ActionMailer::Base.deliveries.size }.by_at_least(1)
    end

    it 'escalates to one-up managers' do
      AccessRequest.update_all(updated_at: 3.days.ago)
      expect { AccessRequest.annoy_managers }
        .to change { ActionMailer::Base.deliveries.size }.by_at_least(1)
    end
  end
end
