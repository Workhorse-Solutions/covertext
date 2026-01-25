Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Twilio webhooks
  namespace :webhooks do
    post "twilio/inbound", to: "twilio_inbound#create"
    post "twilio/status", to: "twilio_status#create"
  end

  # Public document access (for Twilio MMS media URLs)
  namespace :public do
    get "documents/:signed_id", to: "documents#show", as: :document
  end

  # Admin dashboard
  namespace :admin do
    resources :requests, only: [ :index, :show ]
  end

  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Root path
  root "admin/requests#index"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
