Rails.application.routes.draw do
  get 'programs/index'
  root "programs#index"
  get "/settings", to: "settings#index", as: :settings

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :programs do
    collection do
      get :list
    end

    member do
      patch :toggle
    end
  end
end