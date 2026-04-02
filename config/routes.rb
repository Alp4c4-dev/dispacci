Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Home
  root "home#index"

  get "/me", to: "sessions#show"

  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  post "/register", to: "registrations#create"

  post "/commands", to: "commands#create"

  post "/donations", to: "donations#create"

  post "/definitions", to: "word_definitions#create"

  get "map", to: "maps#show"
  post "map/verify", to: "maps#verify"

  get "/payloads/html/:id", to: "payloads#html", as: :html_payload

  get "/games/breakout", to: "games#breakout"
  resources :game_sessions, only: [ :create ]

  get "/kpi", to: "kpis#index"
end
