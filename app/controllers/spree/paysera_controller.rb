require 'base64'
require 'cgi'
require 'digest/md5'
require 'net/http'
require 'uri'
require 'openssl'
require 'open-uri'
module Spree
    class PayseraController < StoreController
        protect_from_forgery only: :index
        def index
            payment_method_id = params[:payment_method_id]
            payment_method = Spree::PaymentMethod.find_by(id: payment_method_id)
            success_url = paysera_confirm_path(payment_method_id)
            callback_url = paysera_callback_path(payment_method_id)
            cancel_url = paysera_cancel_path(payment_method_id)
            service_url = payment_method.preferred_service_url.present? ? payment_method.preferred_service_url : 'https://www.paysera.lt/pay/?'
            order = current_order || raise(ActiveRecord::RecordNotFound)
            amount = order.total*100
            payment_method.preferred_test_mode ? test_value = 1 : test_value = 0
            paytext_value = payment_method.preferred_message_text.present? ? payment_method.preferred_message_text : 'Payment'
            options = {
                orderid: order.number,
                accepturl: payment_method.preferred_domain_name + success_url,
                cancelurl: payment_method.preferred_domain_name + cancel_url,
                callbackurl: payment_method.preferred_domain_name + callback_url,
                amount: amount.to_i,
                currency: order.currency,
                test: test_value,
                paytext: paytext_value,
                p_firstname: order.bill_address.firstname,
                p_lastname: order.bill_address.lastname,
                p_street: order.bill_address.address1 + " " + order.bill_address.address2,
                p_city: order.bill_address.city,
                p_zip: order.bill_address.zipcode
            }
            url = service_url + build_request(options)
            begin
                redirect_to url
            end
        end 
        def callback
            if params[:data].nil? 
                begin
                redirect_to products_path
                end
                return
            end
            payment_method = Spree::PaymentMethod.find_by(id: params[:payment_method_id])
            raise send_error("invalid payment method") if payment_method.type != "Spree::Gateway::Paysera"
            Spree::LogEntry.create({
                source: payment_method,
                details: params.to_yaml
            })
            response = parse(params)
            if response[:projectid].to_i != payment_method.preferred_project_id
                render plain: 'Error: project id does not match'
                return
            end
            order = Spree::Order.find_by(number: response[:orderid])

            money = order.total * 100
            if response[:payamount].to_i != money.to_i
                render plain: 'Error: bad order amount'
                return
            end

            payment = order.payments.create!({
                source_type: 'Spree::Gateway::Paysera',
                amount: order.total,
                payment_method: payment_method
            })
            payment.complete
            order.next

            if order.payment_state == "paid"
                render plain: 'OK'
                return
              else
                render plain: 'Error processing payment'
                return
              end
        end
        def confirm
            payment_method = Spree::PaymentMethod.find_by(id: params[:payment_method_id])
            raise send_error("invalid payment method") if payment_method.type != "Spree::Gateway::Paysera"
            if params[:data].nil? 
                begin
                redirect_to products_path
                end
                return
            end
            response = parse(params)
            raise send_error("'projectid' mismatch") if response[:projectid].to_i != payment_method.preferred_project_id
            order = Spree::Order.find_by(number: response[:orderid])

            if order.payment_state != "paid"
                flash.alert = Spree.t(:payment_processing_failed)
                begin
                redirect_to cart_path
                end
                return
            end

            flash.notice = Spree.t(:order_approved)
            begin
            redirect_to order_path(id: order.number)
            end
            return
        end

        def cancel
            flash.notice = Spree.t(:order_canceled)
            begin
            redirect_to products_path
            end
        end


        private
        PUBLIC_KEY = 'http://www.paysera.com/download/public.key'
        
        def parse(query)
            payment_method = Spree::PaymentMethod.find_by(id: params[:payment_method_id])
            raise send_error("invalid payment method") if payment_method.type != "Spree::Gateway::Paysera"
            render plain: "Error: data not found" if query[:data].nil?
            render plain: "Error: ss1 not found" if query[:ss1].nil?
            render plain: "Error: ss2 not found" if query[:ss2].nil?
      
            projectid ||= payment_method.preferred_project_id
            render plain: "Error: projectid not found" if projectid.nil?
      
            sign_password ||= payment_method.preferred_sign_key
            render plain: "Error: sign_password not found" if sign_password.nil?
      
            render plain: "ss1 verification failed" unless valid_ss1? query[:data], query[:ss1], sign_password
            render plain: "ss2 verification failed" unless valid_ss2? query[:data], query[:ss2]
      
            convert_to_hash decode_string(query[:data])
          end
          def convert_to_hash(query)
            Hash[query.split('&').collect do |s|
                   a = s.split('=')
                   [unescape_string(a[0]).to_sym, unescape_string(a[1])]
                 end]
          end
          def get_public_key
            OpenSSL::X509::Certificate.new(open(PUBLIC_KEY).read).public_key
          end
          def decode_string(string)
            Base64.decode64 string.gsub('-', '+').gsub('_', '/').gsub("\n", '')
          end
          def valid_ss1?(data, ss1, sign_password)
            Digest::MD5.hexdigest(CGI.unescape(data) + sign_password) == ss1
          end
      
          def valid_ss2?(data, ss2)
            public_key = get_public_key
            ss2        = decode_string(unescape_string(ss2))
            data       = unescape_string data
      
            public_key.verify(OpenSSL::Digest::SHA1.new, ss2, data)
          end
          def unescape_string(string)
            CGI.unescape string.to_s
          end


        def build_request(paysera_params)
            payment_method = Spree::PaymentMethod.find_by(id: params[:payment_method_id])
            raise send_error("invalid payment method") if payment_method.type != "Spree::Gateway::Paysera"
            paysera_params             = Hash[paysera_params.map { |k, v| [k.to_sym, v] }]
            paysera_params[:version]   = payment_method.preferred_api_version
            paysera_params[:projectid] = payment_method.preferred_project_id
            sign_password              = payment_method.preferred_sign_key
            valid_request = validate_request(paysera_params)
            encoded_query  = encode_string make_query(valid_request)
            signed_request = sign_request(encoded_query, sign_password)
            query = make_query({
                                   :data => encoded_query,
                                   :sign => signed_request
                               })
            query
        end
          
        def validate_request(req)
            request = {}
            REQUEST.each do |k, v|
            raise "'#{k}' is required but missing" if v[:required] and req[k].nil?
            req_value = req[k].to_s
            regex     = v[:regex].to_s
            maxlen    = v[:maxlen]
            unless req[k].nil?
                raise "'#{k}' value '#{req[k]}' is too long, #{v[:maxlen]} characters allowed." if maxlen and req_value.length > maxlen
                raise "'#{k}' value '#{req[k]}' invalid." if '' != regex and !req_value.match(regex)
                request[k] = req[k]
            end
            end
            request
        end

        def make_query(data)
            data.collect do |key, value|
            "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
            end.compact.sort! * '&'
        end
    
        def sign_request(query, password)
            Digest::MD5.hexdigest(query + password)
        end
    
        def encode_string(string)
            Base64.encode64(string).gsub("\n", '').gsub('/', '_').gsub('+', '-')
        end
    
        REQUEST = {
            :projectid         => {
                :maxlen   => 11,
                :required => true,
                :regex    => /^\d+$/
            },
            :orderid     => {
                :maxlen   => 40,
                :required => true,
            },
            :accepturl   => {
                :maxlen   => 255,
                :required => true,
            },
            :cancelurl   => {
                :maxlen   => 255,
                :required => true,
            },
            :callbackurl => {
                :maxlen   => 255,
                :required => true,
            },
            :version           => {
                :maxlen   => 9,
                :required => true,
                :regex    => /^\d+\.\d+$/
            },
            :lang              => {
                :maxlen   => 3,
                :required => false,
                :regex    => /^[a-z]{3}$/i
            },
            :amount            => {
                :maxlen   => 11,
                :required => false,
                :regex    => /^\d+$/
            },
            :currency          => {
                :maxlen   => 3,
                :required => false,
                :regex    => /^[a-z]{3}$/i
            },
            :payment           => {
                :maxlen   => 20,
                :required => false
            },
            :country           => {
                :maxlen   => 2,
                :required => false,
                :regex    => /^[a-z]{2}$/i
            },
            :paytext           => {
                :maxlen   => 255,
                :required => false,
            },
            :p_firstname       => {
                :maxlen   => 255,
                :required => false,
            },
            :p_lastname        => {
                :maxlen   => 255,
                :required => false,
            },
            :p_email           => {
                :maxlen   => 255,
                :required => false,
            },
            :p_street          => {
                :maxlen   => 255,
                :required => false,
            },
            :p_city            => {
                :maxlen   => 255,
                :required => false,
            },
            :p_state           => {
                :maxlen   => 20,
                :required => false,
            },
            :p_zip             => {
                :maxlen   => 20,
                :required => false,
            },
            :p_countrycode     => {
                :maxlen   => 2,
                :required => false,
                :regex    => /^[a-z]{2}$/i
            },
            :only_payments     => {
                :required => false,
            },
            :disallow_payments => {
                :required => false,
            },
            :test              => {
                :maxlen   => 1,
                :required => false,
                :regex    => /^[01]$/
            },
            :time_limit        => {
                :maxlen   => 19,
                :required => false,
            },
            :personcode        => {
                :maxlen   => 255,
                :required => false,
            },
            :developerid       => {
                :maxlen   => 11,
                :required => false,
                :regex    => /^\d+$/
            }
        }
    end
end
