require 'singleton'

# Mailer bodies that admins can edit at runtime, resolved ahead of the
# on-disk app/views templates by AccessRequestMailer.
class MailerTemplate < ApplicationRecord
  acts_as_change_logger

  validates :body, :path, presence: true
  validates :format, inclusion: { in: -> (_) { ActionView::Template::Types.symbols.map(&:to_s) } }
  validates :locale, inclusion: { in: -> (_) { I18n.available_locales.map(&:to_s) } }
  validates :handler, inclusion: { in: -> (_) { ActionView::Template::Handlers.extensions.map(&:to_s) } }

  after_save { MailerTemplate::Resolver.instance.clear_cache }
  after_destroy { MailerTemplate::Resolver.instance.clear_cache }

  def display_path
    path.gsub(%r{^.*access_request_mailer/}, '').gsub(/\.html\.erb$/, '').humanize
  end

  # An ActionView::Resolver backed by this table.
  #
  # Rails 8 keeps the Resolver#find_templates contract the old implementation
  # used, but ActionView::Template.new now takes keyword arguments and a
  # symbol format rather than a Mime::Type.
  class Resolver < ActionView::Resolver
    include Singleton

    def initialize
      super
      @cache = Concurrent::Map.new
    end

    def clear_cache
      @cache.clear
    end

    private

    def find_templates(name, prefix, partial, details, locals = [])
      conditions = {
        path: normalize_path(name, prefix),
        locale: normalize_array(details[:locale]).first,
        format: normalize_array(details[:formats]).first,
        handler: normalize_array(details[:handlers]),
        partial: partial || false
      }

      MailerTemplate.where(conditions).map { |record| initialize_template(record, locals) }
    end

    def normalize_path(name, prefix)
      prefix.present? ? "#{prefix}/#{name}" : name
    end

    def normalize_array(array)
      Array(array).map(&:to_s)
    end

    def initialize_template(record, locals)
      handler = ActionView::Template.registered_template_handler(record.handler)

      ActionView::Template.new(
        record.body,
        "MailerTemplate - #{record.id} - #{record.path.inspect}",
        handler,
        locals: locals,
        format: record.format.to_sym,
        virtual_path: virtual_path(record.path, record.partial)
      )
    end

    def virtual_path(path, partial)
      return path unless partial

      if (index = path.rindex('/'))
        path.dup.insert(index + 1, '_')
      else
        "_#{path}"
      end
    end
  end
end
