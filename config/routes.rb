Spree::Core::Engine.add_routes do
  post '/paysera', :to => "paysera#index", :as => :paysera_proceed
  get '/paysera/:payment_method_id/callback', :to => "paysera#callback", :as => :paysera_callback
  get '/paysera/:payment_method_id/confirm', :to => "paysera#confirm", :as => :paysera_confirm
  get '/paysera/:payment_method_id/cancel', :to => "paysera#cancel", :as => :paysera_cancel
end