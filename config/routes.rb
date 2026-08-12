Rails.application.routes.draw do
  # ヘルスチェック / cron-jobからの死活監視用。ApplicationControllerを経由しないため認証不要かつ軽量。
  get "up" => "rails/health#show", as: :rails_health_check

  root "programs#index"
  get "/settings", to: "settings#index", as: :settings

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :programs, except: [:new, :show] do
    collection do
      get :list
    end

    member do
      patch :toggle
    end
  end
end