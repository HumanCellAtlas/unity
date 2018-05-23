class AddOauthTokensToUsers < ActiveRecord::Migration[5.2]
  def change
    enable_extension 'hstore' unless extension_enabled?('hstore')
    add_column :users, :access_token, :hstore
    add_column :users, :encrypted_refresh_token, :string
    add_column :users, :encrypted_refresh_token_iv, :string
  end
end
