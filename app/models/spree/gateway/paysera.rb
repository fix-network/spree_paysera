class Spree::Gateway::Paysera < Spree::Gateway
    preference :project_id, :integer
    preference :sign_key, :string
    preference :api_version, :string, default: '1.6'
    preference :domain_name, :string
    preference :message_text, :string
    preference :service_url, :string, default: 'https://www.paysera.lt/pay/?'
    preference :image_url, :string, default: 'https://bank.paysera.com/assets/image/payment_types/wallet.png'

    def provider_class
      Paysera
    end
    def source_required?
        false
    end
    def auto_capture?
        true
    end
  
    def method_type
      'paysera'
    end

    def purchase(amount, transaction_details, options = {})
        ActiveMerchant::Billing::Response.new(true, 'Paysera success', {},{})
    end
    
  end