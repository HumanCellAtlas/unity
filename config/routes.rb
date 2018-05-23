Rails.application.routes.draw do
  scope 'unity' do
    devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }

    get 'about_us', to: 'site#about_us', as: :about_us
    get 'privacy_policy', to: 'site#privacy_policy', as: :privacy_policy
    get '/', to: 'site#index', as: :site
    root to: 'site#index'
  end
end
