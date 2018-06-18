# spree_paysera
Paysera payment gateway integration for Spree Ecommerce


## Installation

1. Add this to your gemfile:

        gem 'spree_paysera', :github => 'donny741/spree_paysera'

2. Install the gem using Bundler:

        bundle install

3. Restart your server

## Setup

In Spree admin panel go to "Configuration", "Payment Methods". Create a new payment method. Select provider "Spree::Gateway::Paysera", enter name and description. Click "Create". Enter project id, domain name (example: https://www.example.com) and message text (paytext).

For production untick "Test Mode"