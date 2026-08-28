class ApplicationMailer < ActionMailer::Base
  # Resolved lazily so the sender can be changed by editing config/app.yml
  # without restarting.
  default from: -> { App.email[:from] }
end
