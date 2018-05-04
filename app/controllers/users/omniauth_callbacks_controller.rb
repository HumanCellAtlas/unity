module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController

    ###
    #
    # This is the OAuth2 endpoint for receiving callbacks from Google after successful authentication
    #
    ###

    def google_oauth2
      # You need to implement the method below in your model (e.g. app/models/user.rb)
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
        sign_in(@user)
        redirect_to request.env['omniauth.origin'] || root_path
      else
        redirect_to new_user_session_path
      end
    end
  end
end
