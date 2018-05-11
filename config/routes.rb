Rails.application.routes.draw do
  scope 'unity' do
    devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
    get 'hello_world', to: 'site#hello_world'

    root to: 'site#hello_world'
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
