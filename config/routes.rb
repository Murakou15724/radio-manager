Rails.application.routes.draw do
  get 'programs/index'
  root "programs#index"
  get "/settings", to: "settings#index", as: :settings

  resources :programs do
    collection do
      get :list
    end

    member do
      patch :toggle
    end
  end
end