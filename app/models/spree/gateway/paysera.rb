class Spree::Gateway::Paysera < Spree::Gateway
    preference :sign_key, :string
    preference :project_id, :integer
    preference :domain_name, :string
    preference :message_text, :string
    preference :service_url, :string, default: 'https://www.paysera.lt/pay/?'
    def self.super
        super
    end
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