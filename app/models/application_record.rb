class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Provides the acts_as_change_logger macro (replaces the change_logger gem).
  include ChangeLoggable
end
