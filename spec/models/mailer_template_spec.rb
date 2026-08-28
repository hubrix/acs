require 'rails_helper'

RSpec.describe MailerTemplate do
  let(:valid_attributes) do
    {
      path: 'access_request_mailer/notify_user_of_request_denial',
      body: 'Overridden body for <%= @user.full_name %>',
      format: 'html',
      locale: 'en',
      handler: 'erb',
      partial: false
    }
  end

  after { MailerTemplate::Resolver.instance.clear_cache }

  describe 'validations' do
    it 'accepts a well formed template' do
      expect(described_class.new(valid_attributes)).to be_valid
    end

    it 'requires a body and a path' do
      template = described_class.new
      template.valid?
      expect(template.errors[:body]).to be_present
      expect(template.errors[:path]).to be_present
    end

    it 'rejects an unknown format' do
      template = described_class.new(valid_attributes.merge(format: 'wat'))
      template.valid?
      expect(template.errors[:format]).to be_present
    end

    it 'rejects an unknown handler' do
      template = described_class.new(valid_attributes.merge(handler: 'haml'))
      template.valid?
      expect(template.errors[:handler]).to be_present
    end

    it 'rejects an unavailable locale' do
      template = described_class.new(valid_attributes.merge(locale: 'kl'))
      template.valid?
      expect(template.errors[:locale]).to be_present
    end
  end

  describe '#display_path' do
    it 'strips the mailer prefix and the extension' do
      template = described_class.new(path: 'access_request_mailer/notify_user_of_request_denial.html.erb')
      expect(template.display_path).to eq('Notify user of request denial')
    end
  end

  # The resolver is an ActionView::Resolver subclass; Rails 8 changed
  # ActionView::Template.new to keyword arguments and a symbol format.
  describe 'MailerTemplate::Resolver' do
    it 'renders a database template in place of the file on disk' do
      MailerTemplate.create!(valid_attributes)
      MailerTemplate::Resolver.instance.clear_cache

      mail = AccessRequestMailer.notify_user_of_request_denial(access_requests(:dengle_us_portal))
      expect(mail.body.encoded).to include("Overridden body for #{users(:dengle).full_name}")
    end

    it 'falls back to the file on disk when no record matches' do
      mail = AccessRequestMailer.notify_user_of_request_denial(access_requests(:dengle_us_portal))
      expect(mail.body.encoded).not_to include('Overridden body')
      expect(mail.body.encoded).to be_present
    end

    it 'prefixes partial paths with an underscore' do
      resolver = MailerTemplate::Resolver.instance
      expect(resolver.send(:virtual_path, 'mailer/thing', true)).to eq('mailer/_thing')
      expect(resolver.send(:virtual_path, 'thing', true)).to eq('_thing')
      expect(resolver.send(:virtual_path, 'mailer/thing', false)).to eq('mailer/thing')
    end
  end
end
