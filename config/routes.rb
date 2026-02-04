Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Marketing & Signup
  root "marketing#index"
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  get "signup/success", to: "registrations#success", as: :signup_success
  post "signup/complete", to: "registrations#complete", as: :signup_complete

  # Twilio webhooks
  namespace :webhooks do
    post "twilio/inbound", to: "twilio_inbound#create"
    post "twilio/status", to: "twilio_status#create"
    post "stripe", to: "stripe_webhooks#create"
  end

  # Public document access (for Twilio MMS media URLs)
  namespace :public do
    get "documents/:signed_id", to: "documents#show", as: :document
  end

  # Admin dashboard
  namespace :admin do
    resources :requests, only: [ :index, :show ]
    get "billing", to: "billing#show"
    resource :account, only: [ :show, :update ]
    post "dismiss_grace_period_banner", to: "banners#dismiss_grace_period"
  end

  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "password/reset", to: "password_resets#new", as: :new_password_reset
  post "password/reset", to: "password_resets#create", as: :password_resets
  get "password/reset/edit", to: "password_resets#edit", as: :edit_password_reset

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
