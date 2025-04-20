Rails.application.routes.draw do
  get "categories/index"
  get "categories/new"
  get "categories/create"
  get "categories/edit"
  get "categories/update"
  get "categories/destroy"
  # RESTful routes for text mappings
  
  resources :text_mappings do
    member do
      post :mark_processed
      post :mark_unprocessed
    end
    
    collection do
      get :import
      post :process_import
      get :bulk_edit
      post :bulk_update
      post :bulk_process
      post :bulk_update_selected
    end
  end
  
  # Category management
  resources :categories
  
  # API routes
  namespace :api do
    namespace :v1 do
      resources :text_mappings, only: [:index] do
        collection do
          post :correct_text
        end
      end
    end
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "text_mappings#index"
end
