Rails.application.routes.draw do
  root to: 'user_sessions#new'

  # Health check for load balancers / Kamal.
  get 'up' => 'rails/health#show', as: :rails_health_check

  resource :user_session, only: %i[new create destroy]
  get 'login' => 'user_sessions#new', as: :login
  match 'logout' => 'user_sessions#destroy', as: :logout, via: %i[get delete]

  # The request phase (POST /auth/:provider) is served by the OmniAuth
  # middleware and never reaches the router; only the return leg is routed.
  # Providers come back by GET (OAuth2/OIDC) or POST (SAML, form_post).
  match 'auth/:provider/callback' => 'omniauth_callbacks#create',
        via: %i[get post], as: :omniauth_callback
  match 'auth/failure' => 'omniauth_callbacks#failure',
        via: %i[get post], as: :omniauth_failure

  get 'dashboard' => 'dashboard#index', as: :dashboard
  get 'dashboard/auto_refresh' => 'dashboard#auto_refresh', as: :auto_refresh

  get 'search' => 'search#index', as: :search

  resource :preferences, only: %i[show update]

  # Static, non-resourceful order matters: these must be declared before
  # `resources :access_requests` so they are not swallowed by the :id segment.
  # Both are reached by GET (a link) and by POST (the resource/subordinate
  # selection form submits into them), which the Rails 3 `match` allowed.
  match 'access_requests/new/permissions' => 'access_requests#permissions',
        as: :new_permissions_access_requests, via: %i[get post]
  # Used for both access_requests/grant/permissions and access_requests/revoke/permissions
  match 'access_requests/:to_do/permissions' => 'access_requests#choose_permissions',
        as: :choose_permissions, via: %i[get post]

  resources :access_requests do
    resources :notes, only: :create
    member do
      post :manager_approval
      post :assign_request
      post :resource_owner_approval
      post :complete
      post :unassign
      post :cancel
    end
    collection do
      get :revoke
      post :revoke_access
      get :help_desk
    end
  end

  # These stay declared as full resources (as in the Rails 3 routes) even
  # though the controllers only implement index/show: several views link to
  # the generated edit_*/new_* helpers.
  resources :requests do
    resources :access_requests
  end

  resources :users do
    resources :requests
  end

  # The "Transfer <name>" control is a button_to, so /transfer/new is reached
  # by POST as well as GET.
  match 'transfer/new' => 'transfer#new', as: :transfer_new, via: %i[get post]
  # form_for on a persisted user submits PATCH.
  match 'transfer/create' => 'transfer#create', as: :transfer_create, via: %i[post patch put]

  resources :resources do
    resources :resource_groups
  end

  resources :resource_groups do
    resources :resources
  end

  resources :jobs do
    resources :users
  end

  resources :departments do
    resources :users
  end

  namespace :admin do
    resources :mailer_templates, only: %i[index edit update] do
      member { get :edit_description }
    end

    resources :roles do
      resources :users, only: :index
    end

    resources :locations do
      resources :departments, only: :index
      resources :users, only: :index
    end

    resources :departments do
      resources :users, only: :index
    end

    resources :jobs do
      resources :users, only: :index
      resources :change_logs, only: :index
      post :activate
    end

    resources :resource_groups do
      resources :resources
      resources :permission_types
    end

    resources :resources do
      post :activate
    end

    resources :terminated_users, only: :index do
      member { post :rehire }
    end

    resources :users do
      member do
        get :review_permissions
        post :set_permissions
        post :terminate
        post :reactivate
        post :hr_confirm
        post :hr_veto
      end
      collection do
        get :import
        post :upload
        get :summary
      end
    end

    resources :employment_types do
      resources :users, only: :index
    end

    resources :change_logs, only: :index
    resources :companies do
      resources :departments, only: :index
      resources :users, only: :index
    end
  end

  get 'admin' => 'admin/resources#index', as: :admin
  match 'admin/users/new/permissions' => 'admin/users#permissions',
      as: :new_permissions_admin_users, via: %i[get post]
end
