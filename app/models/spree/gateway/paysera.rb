class Spree::Gateway::Paysera < Spree::Gateway
    preference :sign_key, :string
    preference :project_id, :integer
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
    def getSignKey
        preferred_sign_key
    end
    def getProjectId
        preferred_project_id
    end

    def purchase(amount, transaction_details, options = {})

        ActiveMerchant::Billing::Response.new(true, 'Paysera success', {},{})
    end
    
  end