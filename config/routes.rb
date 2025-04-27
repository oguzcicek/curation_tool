Rails.application.routes.draw do

  # Text Mapping
  resources :text_mappings do
    member do
      post :mark_processed
      post :mark_unprocessed
      post :set_as_canonical
      post :add_to_canonical
      get :find_canonical_candidates
      get :show_aliases
      post :toggle_hidden
    end
    
    collection do
      get :import
      post :process_import
      get :bulk_edit
      post :bulk_update
      post :bulk_process
      post :bulk_update_selected
      get :show_children
      get :find_duplicates
      post :process_duplicates
      post :create_canonical_relationship
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
          get :hierarchical
          get :canonicals
        end
      end
    end
  end
  

  root "text_mappings#index"
end
