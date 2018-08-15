Rails.application.routes.draw do

  scope 'unity' do

    devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }

    devise_scope :user do
      get 'sign_in', :to => 'devise/sessions#new', :as => :new_user_session
      match 'sign_out', :to => 'users/sessions#destroy', :as => :destroy_user_session, via: :delete
    end

    # admin & reference_analysis routes
    resources :admin_configurations, path: 'admin'
    resources :reference_analyses

    # project routes
    resources :projects, only: [:index, :new, :show, :create, :destroy] do
      member do
        get 'workspaces', to: 'projects#workspaces', as: 'workspaces'
      end
    end
    get 'projects/new/from_scratch', to: 'projects#new_from_scratch', as: :new_project_from_scratch
    post 'projects/new/from_scratch', to: 'projects#create_from_scratch', as: :create_project_from_scratch

    # user_workspaces routes (benchmarking workspaces)
    get 'my-benchmarks', to: 'user_workspaces#index', as: :user_workspaces
    post 'my-benchmarks', to: 'user_workspaces#create', as: :create_user_workspace
    get 'my-benchmarks/new', to: 'user_workspaces#new', as: :new_user_workspace
    get 'my-benchmarks/:project/:name', to: 'user_workspaces#show', as: :user_workspace
    get 'my-benchmarks/:id', to: 'user_workspaces#show' # fallback route
    delete 'my-benchmarks/:project/:name', to: 'user_workspaces#destroy', as: :destroy_user_workspace
    delete 'my-benchmarks/:id', to: 'user_workspaces#destroy' # fallback route
    post 'my-benchmarks/:project/:name/user_analysis', to: 'user_workspaces#create_user_analysis', as: :create_user_analysis
    get 'my-benchmarks/:project/:name/reference_wdl', to: 'user_workspaces#get_reference_wdl_payload', as: :get_reference_wdl

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
