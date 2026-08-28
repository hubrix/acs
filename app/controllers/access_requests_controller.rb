class AccessRequestsController < ApplicationController
  before_action :require_user
  before_action :merge_user_id_with_note, only: %i[manager_approval resource_owner_approval]

  # GET /access_requests
  def index
    @user = params[:user_id].present? ? User.find(params[:user_id]) : current_user
    @access_requests = AccessRequest.involved_user(@user.id).by_created_at.with_extra_info
                                    .paginate(per_page: 50, page: params[:page])
    respond_to do |format|
      format.html
      format.xml { render xml: @access_requests }
    end
  end

  # GET /access_requests/1
  def show
    @access_request = AccessRequest.find(params[:id])
    @request = @access_request.request
    @note = @access_request.notes.new
    respond_to do |format|
      format.html
      format.xml { render xml: @access_request }
    end
  end

  # GET /access_requests/new
  def new
    @access_request = AccessRequest.new
    @resource_groups = ResourceGroup.alphabetical.includes(:resources)
    @subordinates = User.descendants_of(current_user).alphabetical_login if current_user.manager?
    respond_to do |format|
      format.html
      format.xml { render xml: @access_request }
    end
  end

  # GET /access_requests/new/permissions
  def permissions
    # TODO: the two checks below should be moved to the model...
    if params[:user_id].blank? || params[:user_id] == 'For Myself'
      @user = current_user
    else
      @user = User.active.find_by(id: params[:user_id])
      if @user.blank? || !current_user.can_request_access_for?(@user)
        flash[:error] = 'Oops! You are unable to request access for that user.'
        return redirect_to(new_access_request_path)
      end
    end

    if params[:resource_ids].blank?
      flash[:error] = 'Oops! You forgot to select a resource. Please select at least one resource'
      return redirect_to(new_access_request_path)
    end

    @request = Request.new(
      reason: Request::REASONS[:standard],
      created_by: current_user,
      user: @user
    )
    @resources = Resource.where(id: params[:resource_ids])
    @access_requests = @resources.map do |resource|
      @request.access_requests.new(
        resource: resource,
        request_action: AccessRequest::ACTIONS[:grant]
      )
    end
  end

  # POST /access_requests
  # TODO: combine this and revoke_access since they both create access_requests
  # although, revoke_access can create access_requests for multiple resources which
  # could complicate things here instead of making them simpler
  def create
    @request = Request.create(request_params.merge(created_by: current_user))
    @access_requests = []
    submitted_access_requests.each_value do |value|
      access_request = @request.access_requests.build(
        request_action: AccessRequest::ACTIONS[:grant],
        resource_id: value[:resource_id]
      )
      access_request.permission_requests.build(value[:permission_requests_attributes]) if value[:permission_requests_attributes]
      access_request.notes.build(value[:notes_attributes]) if value[:notes_attributes]
      @access_requests << access_request
    end

    while (@access_request = @access_requests.pop)
      if @access_request.valid?
        # TODO: FIXME this doesn't make sense here, the request has already been created
        # so it should be too late to not be allowed
        unless current_user.can_request_access_for?(@request.user)
          @request.destroy
          flash[:error] = "You aren't allowed to do that."
          return redirect_to(dashboard_path)
        end

        if @request.created_by_manager_for_subordinate?
          @access_request.manager = current_user
          @access_request.save
          @access_request.approve_all_permission_requests(@request.reason)
          flash[:notice] = 'Resource owners have been notified about your access request.'
        else
          @access_request.save
          flash[:notice] = 'Access request has been sent to your manager.'
        end
      else
        # Rails 3 fell through to @request.start! here, which silently failed
        # validation. In Rails 8 it raises, so bail out with the errors shown.
        @access_requests << @access_request
        return render('permissions', status: :unprocessable_entity)
      end
    end
    @request.start!
    # TODO: FIXME if users don't enter a note, the request won't transition to in_progress
    # and there will be 'pending' requests left around. This should prevent those,
    # but a much better solution would be to refactor the code above and corresponding
    # view code so that #pop loop above isn't necessary.
    @request.reload # just to be safe here, even though I'm against excessive reloads
    @request.destroy if @request.pending?
    redirect_to dashboard_path if @access_requests.empty?
  end

  # PATCH/PUT /access_requests/1
  def update
    @access_request = AccessRequest.find(params[:id])
    respond_to do |format|
      if @access_request.update(update_params)
        format.html { redirect_to(@access_request, notice: 'Access request was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @access_request.errors, status: :unprocessable_entity }
      end
    end
  end

  def manager_approval
    @access_request = AccessRequest.find(params[:id])
    # TODO: move this into a before_action
    unless current_user.descendants.include?(@access_request.request.user)
      flash[:error] = "You're not a manager of #{@access_request.request.user.full_name}."
      return redirect_to(@access_request)
    end

    @access_request.attributes = { 'manager_approval_attributes' => {} }.merge(approval_params)
    if @access_request.valid? && @access_request.save
      if @access_request.manager_denied_all?
        flash[:notice] = 'All permissions have been denied.'
        @access_request.deny!
      elsif @access_request.resource.has_one_owner?
        @access_request.assign_to(@access_request.resource.users.first)
        flash[:notice] = 'Request has been assigned to ' \
                         "#{@access_request.resource_owner.full_name} for resource owner approval."
      else
        flash[:notice] = 'Notifying resource owners'
        @access_request.send_to_resource_owners!
      end
      redirect_to @access_request
    else
      render_show_with_note
    end
  end

  # TODO: see if this and manager_approval can be combined into a single approval method
  def resource_owner_approval
    @access_request = AccessRequest.find(params[:id])
    unless current_user.resources.include?(@access_request.resource) ||
           current_user.descendants.detect { |desc| desc.resources.include?(@access_request.resource) }
      flash[:error] = "You're not a resource owner of #{@access_request.resource.long_name}."
      return redirect_back(fallback_location: @access_request)
    end

    @access_request.attributes = { 'resource_owner_approval_attributes' => {} }.merge(approval_params)
    if @access_request.valid? && @access_request.save
      if @access_request.resource_owner_denied_all?
        flash[:notice] = 'Denying request.'
        @access_request.deny!
      else
        flash[:notice] = 'Request has been sent to help desk.'
        @access_request.permission_requests.approved_by_resource_owner.each do |permission_request|
          permission_request.update_attribute(:permission_granted, true)
        end
        @access_request.send_to_help_desk!
      end
      redirect_to @access_request
    else
      render_show_with_note
    end
  end

  def assign_request
    @access_request = AccessRequest.find(params[:id])
    if current_user == @access_request.user
      flash[:error] = "You can't assign access requests for you, to yourself."
      return redirect_to(dashboard_path)
    end
    @access_request.assign_to(current_user)
    flash[:notice] = 'Access request has been assigned to you.'
    redirect_to @access_request
  end

  # /access_requests/revoke is where a manager chooses who to revoke access from
  def revoke
    @subordinates = User.active.descendants_of(current_user).alphabetical
  end

  # /access_requests/revoke/permissions is where a manager chooses which permissions
  # to revoke from the user's complete list of permissions
  def choose_permissions
    @user = User.find(params[:user_id])
    @access_request = AccessRequest.new
    @resource_groups = ResourceGroup.accessible_by(@user).alphabetical
  end

  # this is the action choose_permissions submits to
  def revoke_access
    @user = User.find(params[:user_id])
    if params[:resources].blank?
      flash[:error] = 'You need to select at least one permission to revoke.'
      @access_request = AccessRequest.new
      @resource_groups = ResourceGroup.accessible_by(@user).alphabetical
      @resources_with_permissions = Resource.user_has_access(@user)
      return render('choose_permissions', status: :unprocessable_entity)
    end

    @user.generate_revoke_request!(
      created_by: current_user,
      resources: revoke_resource_params
    )

    flash[:notice] = "Request to revoke access for #{@user.full_name} has been sent to help desk."
    redirect_to dashboard_path
  end

  def complete
    @access_request = AccessRequest.find(params[:id])
    @access_request.complete!
    flash[:notice] = 'Access request completed.'
    redirect_to @access_request
  end

  def help_desk
    @requests = Request.with_extra_info.at_help_desk.by_importance
  end

  # DELETE /access_requests/1
  def destroy
    @access_request = AccessRequest.find(params[:id])
    flash[:error] = 'Access requests should not be destroyed.'
    respond_to do |format|
      format.html { redirect_to(access_requests_url) }
      format.xml  { head :ok }
    end
  end

  def unassign
    @access_request = AccessRequest.find(params[:id])
    @access_request.unassign!
    flash[:notice] = 'Access Request has been unassigned'
    redirect_to access_request_path(@access_request)
  end

  def cancel
    @access_request = AccessRequest.find(params[:id])
    if @access_request.can_be_canceled_by?(current_user)
      @access_request.cancel!
      flash[:notice] = 'Access Request has been canceled.'
    else
      flash[:error] = 'You can only cancel access requests that are for you.'
    end
    redirect_to @access_request
  end

  protected

  def render_show_with_note
    @note = @access_request.notes.new
    body = params.dig(:access_request, :notes_attributes)&.first&.dig(:body)
    @note.body = body if body.present?
    @access_request.reload
    @request = @access_request.request
    render 'show', status: :unprocessable_entity
  end

  # TODO: put this in the note class if possible. at least out of here
  def merge_user_id_with_note
    notes = params.dig(:access_request, :notes_attributes)
    notes.first[:user_id] = current_user.id if notes.present?
  end

  def request_params
    params.fetch(:request, {}).permit(:user_id)
  end

  # access_request is submitted as a hash keyed by form index, e.g.
  # access_request[0][resource_id]. Each value is permitted individually.
  def submitted_access_requests
    result = {}
    # ActionController::Parameters is not Enumerable, so each_pair rather than
    # each_with_object.
    params.fetch(:access_request, {}).each_pair do |index, value|
      result[index] = value.permit(
        :resource_id,
        permission_requests_attributes: [:permission_id],
        notes_attributes: %i[body user_id]
      )
    end
    result
  end

  def approval_params
    params.require(:access_request).permit(
      notes_attributes: %i[body user_id],
      manager_approval_attributes: {},
      resource_owner_approval_attributes: {}
    )
  end

  def update_params
    params.require(:access_request).permit(:request_action, :resource_id, :current_worker_id)
  end

  # resources[<resource_id>][permission_ids][] as submitted by choose_permissions.
  def revoke_resource_params
    params.require(:resources).permit!.to_h
  end
end
