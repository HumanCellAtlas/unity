class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:google_oauth2]


  def self.from_omniauth(access_token)
    data = access_token.info
    provider = access_token.provider
    uid = access_token.uid
    # create bogus password, Devise will never use it to authenticate
    password = Devise.friendly_token[0,20]
    # grab user's full name
    full_name = [data['first_name'], data['last_name']].join(' ')
    user = User.find_by(email: data['email'])
    if user.nil?
      user = User.create(email: data["email"],
                         password: password,
                         password_confirmation: password,
                         uid: uid,
                         provider: provider,
                         full_name: full_name)

    elsif user.provider.nil? || user.uid.nil?
      # update info if account was originally local but switching to Google auth
      user.update(provider: provider, uid: uid)
    end
    user
  end
end
