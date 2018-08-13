Rails.application.routes.draw do

  resources :reference_analyses
  scope 'unity' do

    devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }

    devise_scope :user do
      get 'sign_in', :to => 'devise/sessions#new', :as => :new_user_session
      match 'sign_out', :to => 'users/sessions#destroy', :as => :destroy_user_session, via: :delete
    end

    resources :admin_configurations, path: 'admin'

    # project routes
    resources :projects, only: [:index, :new, :show, :create, :destroy] do
      member do
        get 'workspaces', to: 'projects#workspaces', as: 'workspaces'
      end
    end
    get 'projects/new/from_scratch', to: 'projects#new_from_scratch', as: :new_project_from_scratch
    post 'projects/new/from_scratch', to: 'projects#create_from_scratch', as: :create_project_from_scratch

    # profile routes
    get 'profile', to: 'site#profile', as: :profile
    post 'profile', to: 'site#update_user_profile', as: :update_user_profile

    get 'pipelines/:namespace/:name/:snapshot', to: 'site#view_pipeline_wdl', as: :view_pipeline_wdl

    # general routes
    get 'about_us', to: 'site#about_us', as: :about_us
    get 'privacy_policy', to: 'site#privacy_policy', as: :privacy_policy
    get '/', to: 'site#index', as: :site
    root to: 'site#index'
  end
end
