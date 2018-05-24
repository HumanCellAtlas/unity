Rails.application.routes.draw do

  scope 'unity' do

    devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }

    devise_scope :user do
      get 'sign_in', :to => 'devise/sessions#new', :as => :new_user_session
      match 'sign_out', :to => 'users/sessions#destroy', :as => :destroy_user_session, via: :delete
    end

    resources :admin_configurations, path: 'admin'

    get 'profile/:uid', to: 'site#profile', as: :profile
    get 'about_us', to: 'site#about_us', as: :about_us
    get 'privacy_policy', to: 'site#privacy_policy', as: :privacy_policy
    get '/', to: 'site#index', as: :site
    root to: 'site#index'
  end
end
