require 'base64'
require 'cgi'
require 'digest/md5'
require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'open-uri'
module Spree
    class PayseraController < StoreController
        protect_from_forgery only: :index
        def index
            payment_method = Spree::PaymentMethod.find_by(name: "Paysera")
            success_url = paysera_confirm_url.to_s
            callback_url = paysera_callback_url.to_s
            cancel_url = paysera_cancel_url.to_s
            service_url = payment_method.preferred_service_url
            order = current_order || raise(ActiveRecord::RecordNotFound)
            amount = order.total*100
            test_value = 0
            test_value = 1 if ayment_method.preferred_test_mode
            options = {
                orderid: order.number,
                accepturl: payment_method.preferred_domain_name + success_url[21..-1],
                cancelurl: payment_method.preferred_domain_name + cancel_url[21..-1],
                callbackurl: payment_method.preferred_domain_name + callback_url[21..-1],
                amount: amount.to_i,
                currency: 'EUR',
                test: test_value,
                paytext: payment_method.preferred_message_text,
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
            payment_method = Spree::PaymentMethod.find_by(name: "Paysera")
            Spree::LogEntry.create({
                source: payment_method,
                details: params.to_yaml
            })

            #parse response, perform validations etc.
            response = parse(params) unless params[:data].nil?
            #check projectid
            raise send_error("'projectid' mismatch") if response[:projectid].to_i != payment_method.preferred_project_id
            #find order in the database
            order = Spree::Order.find_by(number: response[:orderid])
            #check for order amount
            money = order.total * 100
            puts "money amount" + response[:payamount].to_s + " " + money.to_s
            if response[:payamount].to_i != money.to_i
                flash.alert = 'Malicious transaction detected. Order amount not matched.'
                begin
                redirect_to checkout_state_path(order.state)
                end
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
                #flash.notice = Spree.t(:order_processed_successfully)
                #puts "****OK, payment received"
                render plain: 'OK'
                return
              else
                begin
                redirect_to checkout_state_path(order.state)
                end
                return
              end
        end
        def confirm
            #parse response, perform validations etc.
            response = parse(params) unless params[:data].nil?
            #check projectid
            raise send_error("'projectid' mismatch") if response[:projectid].to_i != payment_method.preferred_project_id
        end
        def cancel
        end


        private
        PAYSERA_PUBLIC_KEY = 'http://www.paysera.com/download/public.key'
        
        def parse(query)
            payment_method = Spree::PaymentMethod.find_by(name: "Paysera")
            raise send_error("'data' parameter was not found") if query[:data].nil?
            raise send_error("'ss1' parameter was not found") if query[:ss1].nil?
            raise send_error("'ss2' parameter was not found") if query[:ss2].nil?
      
            projectid ||= payment_method.preferred_project_id
            raise send_error("'projectid' parameter was not found") if projectid.nil?
      
            sign_password ||= payment_method.preferred_sign_key
            raise send_error("'sign_password' parameter was not found") if sign_password.nil?
      
            raise send_error("Unable to verify 'ss1'") unless valid_ss1? query[:data], query[:ss1], sign_password
            raise send_error("Unable to verify 'ss2'") unless valid_ss2? query[:data], query[:ss2]
      
            convert_to_hash safely_decode_string(query[:data])
      
            
          end
          def convert_to_hash(query)
            Hash[query.split('&').collect do |s|
                   a = s.split('=')
                   [unescape_string(a[0]).to_sym, unescape_string(a[1])]
                 end]
          end
          def get_public_key
            OpenSSL::X509::Certificate.new(open(PAYSERA_PUBLIC_KEY).read).public_key
          end
          def safely_decode_string(string)
            Base64.decode64 string.gsub('-', '+').gsub('_', '/').gsub("\n", '')
          end
          def valid_ss1?(data, ss1, sign_password)
            Digest::MD5.hexdigest(CGI.unescape(data) + sign_password) == ss1
          end
      
          def valid_ss2?(data, ss2)
            public_key = get_public_key
            ss2        = safely_decode_string(unescape_string(ss2))
            data       = unescape_string data
      
            public_key.verify(OpenSSL::Digest::SHA1.new, ss2, data)
          end
          def unescape_string(string)
            CGI.unescape string.to_s
          end


        def build_request(paysera_params)
            payment_method = Spree::PaymentMethod.find_by(name: "Paysera")
            paysera_params             = Hash[paysera_params.map { |k, v| [k.to_sym, v] }]
            paysera_params[:version]   = '1.6'
            paysera_params[:projectid] = payment_method.preferred_project_id
            sign_password              = payment_method.preferred_sign_key
            #puts paysera_params.to_json
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
