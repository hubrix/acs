class NotesController < ApplicationController
  before_action :require_user

  def create
    @access_request = AccessRequest.find(params[:access_request_id])
    @note = @access_request.notes.new(note_params)
    @note.user = current_user
    if @note.save
      flash[:notice] = 'Successfully added comment'
    else
      flash[:error] = 'Note was not saved. Please try again'
    end
    redirect_to @access_request
  end

  private

  def note_params
    params.require(:note).permit(:body)
  end
end
