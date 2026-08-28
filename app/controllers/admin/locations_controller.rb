class Admin::LocationsController < ApplicationController
  before_action :require_admin
  before_action :set_location, only: %i[show edit update destroy]

  def index
    @locations = Location.alphabetical.paginate(page: params[:page],
                                                per_page: current_user.preferred_items_per_page)
    respond_to do |format|
      format.html
      format.xml { render xml: @locations }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @location }
    end
  end

  def new
    @location = Location.new

    respond_to do |format|
      format.html
      format.xml { render xml: @location }
    end
  end

  def edit; end

  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to(admin_locations_path, notice: 'Location was successfully created.') }
        format.xml  { render xml: @location, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to(edit_admin_location_path(@location), notice: 'Location was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @location.destroy

    respond_to do |format|
      format.html { redirect_to(admin_locations_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name)
  end
end
