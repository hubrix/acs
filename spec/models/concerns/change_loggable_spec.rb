require 'rails_helper'

# ChangeLoggable replaces the change_logger gem (0.0.6, 2011).
RSpec.describe ChangeLoggable do
  around do |example|
    ChangeLogger.as('rcooper') { example.run }
  end

  describe 'on create' do
    it 'records one row per non-blank, non-ignored attribute' do
      location = Location.create!(name: 'Austin')
      expect(location.change_logs.pluck(:attribute_name)).to include('name')
      expect(location.change_logs.pluck(:new_value)).to include('Austin')
    end

    it 'records who made the change' do
      location = Location.create!(name: 'Austin')
      expect(location.change_logs.first.changed_by).to eq('rcooper')
    end

    it 'marks the entries as creations' do
      location = Location.create!(name: 'Austin')
      expect(location.change_logs.first.old_value).to eq(ChangeLoggable::ACTIONS[:create])
    end

    it 'skips ignored attributes' do
      user = users(:dengle)
      expect(user.class.change_log_ignored_attributes).to include('crypted_password', 'lft', 'rgt')
    end
  end

  describe 'on update' do
    # Rails 5.1 made `changes` empty inside after_update, so the concern reads
    # saved_changes instead. This is the regression that guards that.
    it 'records the before and after values' do
      location = locations(:chicago)
      location.update!(name: 'Chicago Loop')
      entry = location.change_logs.find_by(attribute_name: 'name')
      expect(entry.old_value).to eq('Chicago, Il')
      expect(entry.new_value).to eq('Chicago Loop')
    end

    it 'does not record anything when nothing changed' do
      location = locations(:chicago)
      expect { location.update!(name: location.name) }.not_to(change { ChangeLog.count })
    end

    it 'increments the revision column when the model has one' do
      job = jobs(:opssupport)
      expect { job.update!(lawson_cd: 'ABC') }.to change { job.reload.revision }.by(1)
    end
  end

  describe 'on destroy' do
    it 'records the attributes that were removed' do
      location = Location.create!(name: 'Austin')
      location.change_logs.delete_all
      location.destroy
      expect(ChangeLog.where(item_type: 'Location', item_id: location.id).pluck(:new_value))
        .to include(ChangeLoggable::ACTIONS[:delete])
    end
  end

  describe 'has_and_belongs_to_many callbacks' do
    it 'records individual additions for untracked associations' do
      resource = resources(:wiki)
      expect { resource.users << users(:mstreet) }
        .to change { resource.change_logs.where(attribute_name: 'User').count }.by(1)
    end

    it 'collapses tracked template associations into a single entry' do
      job = jobs(:opssupport)
      job.permissions << permissions(:wiki_admin)
      job.permissions << permissions(:jira_admin)
      job.save!
      entries = job.change_logs.where(attribute_name: 'permissions_template')
      expect(entries.count).to eq(1)
    end

    it 'stores the template snapshot as safely loadable YAML' do
      job = jobs(:opssupport)
      job.permissions << permissions(:wiki_admin)
      job.save!
      entry = job.change_logs.find_by(attribute_name: 'permissions_template')
      expect(entry.value).to be_an(Array)
      expect(entry.value.first).to include('id')
    end
  end

  describe 'ChangeLogger.whodunnit' do
    it 'is scoped to the current execution' do
      expect(ChangeLogger.whodunnit).to eq('rcooper')
      ChangeLogger.as('someone-else') { expect(ChangeLogger.whodunnit).to eq('someone-else') }
      expect(ChangeLogger.whodunnit).to eq('rcooper')
    end
  end
end
