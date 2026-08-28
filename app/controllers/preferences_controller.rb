class PreferencesController < ApplicationController
  before_action :require_user

  def show
    @preferences = current_user.preferences
  end

  def update
    @user = current_user
    # Preferenceable writes straight to the preferences table, so unlike the
    # old plugin there is nothing left to save on the user record afterwards.
    @user.attributes = preference_params
    flash[:notice] = 'Preferences updated'
    redirect_to preferences_path
  end

  private

  def preference_params
    params.require(:preferences).permit(:preferred_items_per_page, preferred_viewable_departments: [])
  end
end
