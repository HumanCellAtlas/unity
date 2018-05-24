class UnityMailer < ApplicationMailer
  default from: 'no-reply@broadinstitute.org'

  # generic admin notification email method
  def admin_notification(subject, requester, message)
    # don't deliver if config value is set to true
    unless Rails.application.config.disable_admin_notifications == true
      @subject = subject
      @requester = requester.nil? ? 'no-reply@broadinstitute.org' : requester
      @message = message
      @admins = User.where(admin: true).map(&:email)

      unless @admins.empty?
        mail(to: @admins, reply_to: @requester, subject: "[Unity Admin Notification#{Rails.env != 'production' ? " (#{Rails.env})" : nil}]: #{@subject}") do |format|
          format.html
        end
      end
    end
  end
end
