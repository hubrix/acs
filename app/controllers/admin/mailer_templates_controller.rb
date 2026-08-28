class Admin::MailerTemplatesController < ApplicationController
  before_action :require_admin_or_hr
  before_action :set_mailer_template, only: %i[edit edit_description update]

  def index
    @mailer_templates = MailerTemplate.paginate(page: params[:page],
                                                per_page: current_user.preferred_items_per_page)
  end

  def edit; end

  def edit_description; end

  def update
    respond_to do |format|
      if @mailer_template.update(mailer_template_params)
        format.html do
          redirect_to(edit_admin_mailer_template_path(@mailer_template),
                      notice: 'Email template was successfully updated.')
        end
        format.xml { head :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.xml  { render xml: @mailer_template.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_mailer_template
    @mailer_template = MailerTemplate.find(params[:id])
  end

  def mailer_template_params
    params.require(:mailer_template).permit(:body, :description, :path, :format, :locale, :handler, :partial)
  end
end
