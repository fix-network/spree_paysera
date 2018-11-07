module Spree
  CheckoutController.class_eval do
    before_action :paysera_redirect, only: [:update]

    private

    def paysera_redirect
      return unless (params[:state] == 'payment') && params[:order][:payments_attributes]

      payment_method = PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])

      if payment_method.kind_of?(Spree::Gateway::Paysera)
        redirect_to paysera_proceed_url(payment_method_id: payment_method.id)
      end

    end
  end
end