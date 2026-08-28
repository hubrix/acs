class Admin::EmploymentTypesController < ApplicationController
  before_action :require_admin
  before_action :set_employment_type, only: %i[show edit update destroy]

  def index
    @employment_types = EmploymentType.all

    respond_to do |format|
      format.html
      format.xml { render xml: @employment_types }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @employment_type }
    end
  end

  def new
    @employment_type = EmploymentType.new

    respond_to do |format|
      format.html
      format.xml { render xml: @employment_type }
    end
  end

  def edit; end

  def create
    @employment_type = EmploymentType.new(employment_type_params)

    respond_to do |format|
      if @employment_type.save
        format.html do
          redirect_to(admin_employment_types_path, notice: 'Employment type was successfully created.')
        end
        format.xml { render xml: @employment_type, status: :created, location: @employment_type }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @employment_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @employment_type.update(employment_type_params)
        format.html do
          redirect_to(edit_admin_employment_type_path(@employment_type),
                      notice: 'Employment type was successfully updated.')
        end
        format.xml { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @employment_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @employment_type.destroy

    respond_to do |format|
      format.html { redirect_to(admin_employment_types_url) }
      format.xml  { head :ok }
    end
  end

  private

  def set_employment_type
    @employment_type = EmploymentType.find(params[:id])
  end

  def employment_type_params
    params.require(:employment_type).permit(:name)
  end
end
