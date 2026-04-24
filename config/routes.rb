Rails.application.routes.draw do
  get 'programs/index'
  root "programs#index"
  resources :programs do
    collection do
      get :list
    end

    member do
      patch :toggle
    end
  end
end