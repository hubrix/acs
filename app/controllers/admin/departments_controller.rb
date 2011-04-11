class Admin::DepartmentsController < ApplicationController
  before_filter :require_admin
  # GET /departments
  # GET /departments.xml
  def index
    if !params[:location_id].blank?
      @departments = Department.by_location(params[:location_id]).paginate(:per_page => current_user.preferred_items_per_page, :page => params[:page])
    # elsif !params[:department_id].blank?
      # @users = User.by_department(params[:department_id]).sort_by_last_name_first_name.paginate(:per_page => current_user.preferred_items_per_page, :page => params[:page])
    else
      @departments = Department.paginate(:per_page => current_user.preferred_items_per_page, :page => params[:page])
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @departments }
    end
  end

  # GET /departments/1
  # GET /departments/1.xml
  def show
    @department = Department.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @department }
    end
  end

  # GET /departments/new
  # GET /departments/new.xml
  def new
    @department = Department.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @department }
    end
  end

  # GET /departments/1/edit
  def edit
    @department = Department.find(params[:id])
    @users = @department.users.active.alphabetical_login.paginate(:page => params[:page], :per_page => current_user.preferred_items_per_page)
  end

  # POST /departments
  # POST /departments.xml
  def create
    @department = Department.new(params[:department])

    respond_to do |format|
      if @department.save
        format.html { redirect_to(admin_departments_path, :notice => 'Department was successfully created.') }
        format.xml  { render :xml => @department, :status => :created, :location => @department }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @department.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /departments/1
  # PUT /departments/1.xml
  def update
    @department = Department.find(params[:id])

    respond_to do |format|
      if @department.update_attributes(params[:department])
        format.html { redirect_to(edit_admin_department_path(@department), :notice => 'Department was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @department.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /departments/1
  # DELETE /departments/1.xml
  def destroy
    @department = Department.find(params[:id])
    @department.destroy

    respond_to do |format|
      format.html { redirect_to(admin_departments_url) }
      format.xml  { head :ok }
    end
  end
end