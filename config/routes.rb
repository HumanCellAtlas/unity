Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }

  devise_scope :user do
    get 'sign_in', :to => 'devise/sessions#new', :as => :new_user_session
    match 'sign_out', :to => 'users/sessions#destroy', :as => :destroy_user_session, via: :delete
  end

  # admin & reference_analysis routes
  resources :admin_configurations, path: 'admin'
  get 'admin/service_account/profile', to: 'admin_configurations#get_service_account_profile', as: :get_service_account_profile
  post 'admin/service_account/profile', to: 'admin_configurations#update_service_account_profile', as: :update_service_account_profile
  get 'admin/users/:id/edit', to: 'admin_configurations#edit_user', as: :edit_user
  match 'admin/users/:id', to: 'admin_configurations#update_user', via: [:post, :patch], as: :update_user

  resources :reference_analyses do
    member do
      put 'reset_wdl_params', to: 'reference_analyses#reset_wdl_params', as: :reset_wdl_params
    end
  end

  # project routes
  resources :projects, only: [:index, :new, :show, :create, :destroy] do
    member do
      get 'workspaces', to: 'projects#workspaces', as: 'workspaces'
    end
  end
  get 'projects/new/from_scratch', to: 'projects#new_from_scratch', as: :new_project_from_scratch
  post 'projects/new/from_scratch', to: 'projects#create_from_scratch', as: :create_project_from_scratch

  # user_workspace, user_analysis, and benchmark_analysis routes
  get 'my-benchmarks', to: 'user_workspaces#index', as: :user_workspaces
  post 'my-benchmarks', to: 'user_workspaces#create', as: :create_user_workspace
  get 'my-benchmarks/new', to: 'user_workspaces#new', as: :new_user_workspace
  get 'my-benchmarks/:project/:name', to: 'user_workspaces#show', as: :user_workspace
  get 'my-benchmarks/:id', to: 'user_workspaces#show' # fallback route
  delete 'my-benchmarks/:project/:name', to: 'user_workspaces#destroy', as: :destroy_user_workspace
  delete 'my-benchmarks/:id', to: 'user_workspaces#destroy' # fallback route
  post 'my-benchmarks/:project/:name/user_analysis', to: 'user_workspaces#create_user_analysis', as: :create_user_analysis
  post 'my-benchmarks/:project/:name/user_analysis/:user_analysis_id', to: 'user_workspaces#update_user_analysis', as: :update_user_analysis
  get 'my-benchmarks/:project/:name/analysis_wdl', to: 'user_workspaces#get_analysis_wdl_payload', as: :get_analysis_wdl
  post 'my-benchmarks/:project/:name/user_analysis/:user_analysis_id/benchmark_analyses', to: 'user_workspaces#create_benchmark_analysis', as: :create_benchmark_analysis
  post 'my-benchmarks/:project/:name/user_analysis/:user_analysis_id/benchmark_analyses/:benchmark_analysis_id', to: 'user_workspaces#submit_benchmark_analysis', as: :submit_benchmark_analysis
  get 'my-benchmarks/:project/:name/download', to: 'user_workspaces#download_benchmark_output', as: :download_benchmark_output, constraints: {filename: /.*/}
  # user_workspace submission methods
  get 'my-benchmarks/:project/:name/submissions', to: 'user_workspaces#get_workspace_submissions', as: :get_workspace_submissions
  get 'my-benchmarks/:project/:name/submissions/:submission_id', to: 'user_workspaces#get_submission_workflow', as: :get_submission_workflow
  delete 'my-benchmarks/:project/:name/submissions/:submission_id', to: 'user_workspaces#abort_submission_workflow', as: :abort_submission_workflow
  delete 'my-benchmarks/:project/:name/submissions/:submission_id/outputs', to: 'user_workspaces#delete_submission_files', as: :delete_submission_files
  get 'my-benchmarks/:project/:name/submissions/:submission_id/outputs', to: 'user_workspaces#get_submission_outputs', as: :get_submission_outputs
  get 'my-benchmarks/:project/:name/submissions/:submission_id/errors', to: 'user_workspaces#get_submission_errors', as: :get_submission_errors

  # profile routes
  get 'profile', to: 'site#profile', as: :profile
  post 'profile', to: 'site#update_user_profile', as: :update_user_profile


  # general routes
  get 'pipelines/:namespace/:name/:snapshot', to: 'site#view_pipeline_wdl', as: :view_pipeline_wdl
  get 'about_us', to: 'site#about_us', as: :about_us
  get 'privacy_policy', to: 'site#privacy_policy', as: :privacy_policy
  get '/', to: 'site#index', as: :site
  root to: 'site#index'
end
