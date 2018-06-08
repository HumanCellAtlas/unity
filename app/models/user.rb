class User < ApplicationRecord
  attribute :access_token, :hstore
  attribute :admin, :boolean
  attribute :full_name, :string
  attribute :registered_for_firecloud, :boolean, default: false
  attr_encrypted :refresh_token, key: ENV['ENCRYPTION_KEY']

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :registerable, :rememberable, :trackable,
         :omniauthable, :omniauth_providers => [:google_oauth2]

  # Associations
  has_many :projects, dependent: :delete_all

  def self.from_omniauth(access_token)
    data = access_token.info
    provider = access_token.provider
    uid = access_token.uid
    # grab user's full name
    full_name = [data['first_name'], data['last_name']].join(' ')
    user = User.find_by(email: data['email'])
    if user.nil?
      user = User.create(email: data["email"],
                         uid: uid,
                         provider: provider,
                         full_name: full_name)

    elsif user.provider.nil? || user.uid.nil?
      # update info if account was originally local but switching to Google auth
      user.update(provider: provider, uid: uid)
    end

    # store refresh token
    if access_token.credentials.refresh_token.present?
      user.update(refresh_token: access_token.credentials.refresh_token)
    end
    user
  end

  # generate an access token based on user's refresh token
  def generate_access_token
    if self.refresh_token.present?
      begin
        response = RestClient.post 'https://accounts.google.com/o/oauth2/token',
                                   :grant_type => 'refresh_token',
                                   :refresh_token => self.refresh_token,
                                   :client_id => ENV['OAUTH_CLIENT_ID'],
                                   :client_secret => ENV['OAUTH_CLIENT_SECRET']
        token_vals = JSON.parse(response.body)
        expires_at = DateTime.now + token_vals['expires_in'].to_i.seconds
        user_access_token = {'access_token' => token_vals['access_token'], 'expires_in' => token_vals['expires_in'], 'expires_at' => expires_at}
        self.update!(access_token: user_access_token)
        user_access_token
      rescue RestClient::BadRequest => e
        Rails.logger.error "#{Time.now}: Unable to generate access token for user #{self.email}; refresh token is invalid."
        nil
      rescue => e
        Rails.logger.error "#{Time.now}: Unable to generate access token for user #{self.email} due to unknown error; #{e.message}"
      end
    else
      nil
    end
  end

  # check timestamp on user access token expiry
  def access_token_expired?
    self.access_token.blank? ? true : Time.at(DateTime.parse(self.access_token['expires_at'])) < Time.now
  end

  # return an valid access token (will renew if expired)
  def valid_access_token
    self.access_token_expired? ? self.generate_access_token : self.access_token
  end
end
