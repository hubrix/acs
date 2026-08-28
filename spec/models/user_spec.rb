require 'rails_helper'

RSpec.describe User do
  describe 'a new user' do
    subject(:user) { described_class.new }

    before { user.valid? }

    it 'wants a first name' do
      expect(user.errors[:first_name]).to include('is required for every employee')
    end

    it 'wants a last name' do
      expect(user.errors[:last_name]).to include('is required for every employee')
    end

    it 'wants a job' do
      expect(user.errors[:job]).to include('is required')
    end

    it 'wants a manager' do
      expect(user.errors[:base]).to include('User must be created with a manager')
    end

    it 'wants an employment type' do
      expect(user.errors[:employment_type]).to include('is required')
    end

    it 'assigns the default Public role rather than complaining about roles' do
      expect(user.roles).to eq([Role.find_by(name: Role::ROLES[:public])])
      expect(user.errors[:roles]).to be_empty
    end
  end

  describe 'creation' do
    let(:attributes) do
      {
        first_name: 'John',
        last_name: 'Doe',
        job: jobs(:opssupport),
        manager: users(:rcooper),
        company: companies(:example_co),
        employment_type: employment_types(:full_time)
      }
    end

    it 'is valid' do
      expect(described_class.new(attributes)).to be_valid
    end

    it 'generates a login from the first initial and last name' do
      user = described_class.create!(attributes)
      expect(user.login).to eq('jdoe')
    end

    it 'generates an email address from the login and company domain' do
      user = described_class.create!(attributes)
      expect(user.email).to eq('jdoe@example.com')
    end

    it 'rejects a deactivated job' do
      jobs(:opssupport).deactivate!
      user = described_class.new(attributes)
      user.valid?
      expect(user.errors[:job]).to include('must be active')
    end

    it 'requires the job to have a permission template' do
      user = described_class.new(attributes.merge(job: jobs(:recruiting_coordinator)))
      jobs(:recruiting_coordinator).permissions.clear
      user.valid?
      expect(user.errors[:job]).to include('must have a template')
    end
  end

  describe 'authentication' do
    # The fixtures carry Authlogic 2 Sha512 digests; the model configures
    # SCrypt with a Sha512 transition so they must still validate.
    it 'accepts a password hashed by the legacy Sha512 provider' do
      expect(users(:dengle).valid_password?('asdfasdf')).to be(true)
    end

    it 'rejects the wrong password' do
      expect(users(:dengle).valid_password?('nope')).to be(false)
    end

    it 'rehashes the password with SCrypt once it is set again' do
      user = users(:dengle)
      user.password = 'somethinglonger'
      user.save!
      expect(user.crypted_password).not_to match(/\A[0-9a-f]{128}\z/)
      expect(user.reload.valid_password?('somethinglonger')).to be(true)
    end
  end

  describe 'the org chart' do
    it 'exposes descendants through the nested set on manager_id' do
      expect(users(:timothyho).descendants).to include(users(:dengle), users(:alee))
    end

    it 'treats direct reports as first level children' do
      expect(users(:rcooper).direct_manager_of).to eq([users(:dengle)])
    end

    it 'lets a manager request access for a subordinate' do
      expect(users(:rcooper).can_request_access_for?(users(:dengle))).to be(true)
    end

    it 'does not let a peer request access for someone else' do
      expect(users(:dengle).can_request_access_for?(users(:alee))).to be(false)
    end

    it 'always lets a user request access for themselves' do
      expect(users(:dengle).can_request_access_for?(users(:dengle))).to be(true)
    end

    it 'lets HR request access for anyone' do
      expect(users(:nott).can_request_access_for?(users(:alee))).to be(true)
    end
  end

  describe 'roles' do
    it 'recognises admins' do
      expect(users(:rcooper)).to be_admin
    end

    it 'recognises HR' do
      expect(users(:nott)).to be_hr
    end

    it 'recognises help desk members' do
      expect(users(:jserrano)).to be_help_desk
    end

    it 'supports multiple roles per user' do
      expect(users(:mstreet)).to be_help_desk
      expect(users(:mstreet)).to be_admin
    end
  end

  describe 'scopes' do
    it 'finds active users' do
      expect(described_class.active).to include(users(:dengle))
      expect(described_class.active).not_to include(users(:egarret))
    end

    it 'finds terminated users through the AASM state scope' do
      expect(described_class.terminated).to include(users(:egarret), users(:holajuwon))
    end

    it 'finds users waiting on HR' do
      expect(described_class.waiting_for_hr).to include(users(:jrocket), users(:tguy))
    end

    it 'finds help desk members by role' do
      expect(described_class.help_desk).to include(users(:jserrano), users(:mstreet))
      expect(described_class.help_desk).not_to include(users(:dengle))
    end

    it 'filters by department' do
      expect(described_class.by_department(departments(:it_admin).id))
        .to include(users(:rcooper), users(:dengle))
    end

    it 'filters by location' do
      expect(described_class.by_location(locations(:chicago).id)).to include(users(:dengle))
    end

    it 'filters by partial last name, case insensitively' do
      expect(described_class.last_name('COOP')).to eq([users(:rcooper)])
    end
  end

  describe 'the state machine' do
    it 'starts passive' do
      expect(described_class.new.current_state).to eq('passive')
    end

    it 'stamps activated_at and clears deleted_at on activation' do
      user = users(:tguy)
      user.activate!
      expect(user.reload).to be_active
      expect(user.activated_at).to be_present
      expect(user.deleted_at).to be_nil
    end

    it 'stamps deleted_at and end_date on termination' do
      user = users(:alee)
      user.terminate!
      expect(user.reload).to be_terminated
      expect(user.deleted_at).to be_present
      expect(user.end_date).to eq(Date.today)
    end

    it 'refuses to rehire while a termination request is open' do
      user = users(:holajuwon)
      expect(user.has_no_open_terminations).to be(false)
      expect(user.rehire).to be(false)
      expect(user.reload).to be_terminated
    end

    it 'clears terminated_by when a suspended user is reactivated' do
      user = users(:jrocket)
      user.update_columns(terminated_by_id: users(:nott).id)
      user.reload.reactivate!
      expect(user.reload.terminated_by).to be_nil
    end

    it 'emails HR when a user moves to pending' do
      user = users(:alee)
      user.update_column(:current_state, 'passive')
      expect { user.reload.verify_with_hr! }
        .to change { ActionMailer::Base.deliveries.size }.by(User.hr.count)
    end
  end

  describe 'preferences' do
    it 'falls back to the declared default' do
      expect(users(:dengle).preferred_items_per_page).to eq(20)
    end

    it 'persists and type casts a scalar preference' do
      user = users(:dengle)
      user.preferred_items_per_page = '40'
      expect(user.reload.preferred_items_per_page).to eq(40)
    end

    it 'persists an array preference' do
      user = users(:dengle)
      ids = [departments(:it_admin).id, departments(:uk_ops).id]
      user.preferred_viewable_departments = ids
      expect(user.reload.preferred_viewable_departments).to eq(ids)
    end

    it 'reports every department as viewable until the preference is set' do
      expect(users(:dengle).viewable_departments).to match_array(Department.pluck(:id))
    end

    it 'reports only the chosen departments once set' do
      user = users(:dengle)
      user.preferred_viewable_departments = [departments(:uk_ops).id]
      expect(user.reload.viewable_departments).to eq([departments(:uk_ops).id])
    end
  end

  describe 'display helpers' do
    it 'prefers the nickname when one is set' do
      user = users(:dengle)
      user.update_column(:nickname, 'Dee')
      expect(user.reload.full_name).to eq('Dee Engle')
    end

    it 'falls back to the first name' do
      expect(users(:rcooper).full_name).to eq('Roland Cooper')
    end

    it 'renders last name first' do
      expect(users(:rcooper).last_name_first).to eq('Cooper, Roland')
    end
  end

  describe 'full text search' do
    it 'matches on a login prefix' do
      expect(described_class.full_text_search('rcoo')).to include(users(:rcooper))
    end

    it 'matches on a last name' do
      expect(described_class.full_text_search('Cooper')).to include(users(:rcooper))
    end

    it 'returns nothing for a miss' do
      expect(described_class.full_text_search('zzzznope')).to be_empty
    end
  end

  describe '#stop_bad_delete' do
    it 'refuses to destroy the last active user' do
      described_class.where.not(id: users(:dengle).id).update_all(current_state: 'terminated')
      expect(users(:dengle).destroy).to be(false)
      expect(described_class.exists?(users(:dengle).id)).to be(true)
    end
  end
end
