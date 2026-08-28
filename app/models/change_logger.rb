# Records who is responsible for the change currently being persisted.
#
# Replaces the change_logger gem (last released in 2011, incompatible with
# Rails 5+). The value is set per-request by
# ApplicationController#set_whodunnit and read by ChangeLoggable#record_change.
module ChangeLogger
  class << self
    def whodunnit
      store[:whodunnit]
    end

    def whodunnit=(value)
      store[:whodunnit] = value
    end

    # Runs a block with a given actor, restoring the previous one afterwards.
    def as(actor)
      previous = whodunnit
      self.whodunnit = actor
      yield
    ensure
      self.whodunnit = previous
    end

    private

    # ActiveSupport::IsolatedExecutionState is fiber/thread aware and is reset
    # between requests, unlike the raw Thread.current the gem used.
    def store
      ActiveSupport::IsolatedExecutionState[:change_logger] ||= {}
    end
  end
end
