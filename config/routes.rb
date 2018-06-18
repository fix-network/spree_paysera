Spree::Core::Engine.add_routes do
  post '/paysera', :to => "paysera#index", :as => :paysera_proceed
  get '/paysera/callback', :to => "paysera#callback", :as => :paysera_callback
  get '/paysera/confirm', :to => "paysera#confirm", :as => :paysera_confirm
  get '/paysera/cancel', :to => "paysera#cancel", :as => :paysera_cancel
end