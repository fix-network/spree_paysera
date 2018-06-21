module SpreePaypalExpress
    module Generators
      class InstallGenerator < Rails::Generators::Base
        def add_javascripts
          append_file 'vendor/assets/javascripts/spree/frontend/all.js', "//= require spree/frontend/spree_paypal_express\n"
        end
  
        def add_stylesheets
          frontend_css_file = "vendor/assets/stylesheets/spree/frontend/all.css"
  
          if File.exist?(frontend_css_file)
            inject_into_file frontend_css_file, " *= require spree/frontend/spree_paypal_express\n", :before => /\*\//, :verbose => true
          end
        end
      end
    end
  end