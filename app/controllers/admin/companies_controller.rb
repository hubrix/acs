class Admin::CompaniesController < ApplicationController
  before_action :require_admin
  before_action :set_company, only: %i[show edit update destroy]

  def index
    @companies = Company.all

    respond_to do |format|
      format.html
      format.xml { render xml: @companies }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xml { render xml: @company }
    end
  end

  def new
    @company = Company.new

    respond_to do |format|
      format.html
      format.xml { render xml: @company }
    end
  end

  def edit; end

  def create
    @company = Company.new(company_params)

    respond_to do |format|
      if @company.save
        format.html { redirect_to(admin_companies_path, notice: 'Company was successfully created.') }
        format.xml  { render xml: @company, status: :created, location: @company }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.xml  { render xml: @company.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @company.update(company_params)
        format.html { redirect_to(admin_companies_path, notice: 'Company was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @company.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @company.destroy

    respond_to do |format|
      format.html { redirect_to(admin_companies_path) }
      format.xml  { head :ok }
    end
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:name, :email_domain)
  end
end
