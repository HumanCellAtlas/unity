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

  # notifier of FireCloud API service interruptions
  def firecloud_api_notification(current_status, requester)
    unless Rails.application.config.disable_admin_notifications == true
      @admins = User.where(admin: true).map(&:email)
      @requester = requester.nil? ? 'no-reply@broadinstitute.org' : requester
      @current_status = current_status
      unless @admins.empty?
        mail(to: @admins, reply_to: @requester, subject: "[Unity Admin Notification#{Rails.env != 'production' ? " (#{Rails.env})" : nil}]: ALERT: FIRECLOUD API SERVICE INTERRUPTION") do |format|
          format.html
        end
      end
    end
  end
end
