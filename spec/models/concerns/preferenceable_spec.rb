require 'rails_helper'

# Preferenceable replaces the vendored `preferences` plugin (2010), keeping the
# plugin's accessor names and the existing preferences table.
RSpec.describe Preferenceable do
  let(:user) { users(:dengle) }

  it 'declares the preferences the app uses' do
    expect(User.preference_definitions.keys).to match_array(%w[items_per_page viewable_departments])
  end

  describe 'reading' do
    it 'returns the declared default when nothing is stored' do
      expect(user.preferred_items_per_page).to eq(20)
    end

    it 'returns nil for an array preference with no default' do
      expect(user.preferred_viewable_departments).to be_nil
    end

    it 'exposes every preference as a hash' do
      expect(user.preferences).to eq(
        'items_per_page' => 20,
        'viewable_departments' => nil
      )
    end

    it 'raises for an unknown preference' do
      expect { user.read_preference(:nope) }.to raise_error(ArgumentError, /no preference named/)
    end
  end

  describe 'writing' do
    it 'persists immediately for a saved record' do
      user.preferred_items_per_page = 60
      expect(Preference.where(owner: user, name: 'items_per_page').first.value).to eq('60')
    end

    it 'casts on read according to the declared type' do
      user.preferred_items_per_page = '60'
      expect(user.reload.preferred_items_per_page).to eq(60)
    end

    it 'round-trips array preferences through YAML' do
      user.preferred_viewable_departments = %w[1 2 3]
      expect(user.reload.preferred_viewable_departments).to eq(%w[1 2 3])
    end

    it 'updates rather than duplicating an existing preference row' do
      user.preferred_items_per_page = 40
      expect { user.preferred_items_per_page = 80 }
        .not_to(change { Preference.where(owner: user, name: 'items_per_page').count })
      expect(user.reload.preferred_items_per_page).to eq(80)
    end

    it 'generates the plugin-compatible predicate' do
      expect(user.prefers_items_per_page?).to be(true)
      expect(user.prefers_viewable_departments?).to be(false)
    end
  end

  it 'destroys stored preferences along with the owner' do
    user.preferred_items_per_page = 40
    expect { users(:jfaceless).destroy }.not_to raise_error
    expect { user.destroy }.to change { Preference.where(owner_id: user.id).count }.to(0)
  end
end
