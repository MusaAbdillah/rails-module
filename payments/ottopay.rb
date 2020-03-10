module Ottopay
	class Insert
		
		def initialize(transaction_order, callback_url, webhook_url)
			@transaction_order 		= transaction_order
			@body 					= generate_body(transaction_order, callback_url, webhook_url)
			@headers 				= generate_headers(@body)
		end

		attr_reader :transaction_order, :body, :headers

		def call

			Rails.logger.info "OUR BODY REQUEST TO OTTOPAY============================================="
			Rails.logger.info body
			Rails.logger.info "END OF OUR BODY REQUEST TO OTTOPAY============================================="
			
			request = HTTParty.post(
				"#{ENV["OTTOPAY_BASE_URL"]}v1.0.1/perform/token",
				body: body.to_json,
				headers: headers
				).body

			parsed_request = JSON.parse(request)
			
			ottopay_payment = transaction_order.ottopay_payment.update(
				status_code: parsed_request['responseData']['statusCode'],
				status_message: parsed_request['responseData']['statusMessage'],
				transaction_id: parsed_request['responseData']['transactionId'],
				endpoint_url: "#{ENV['OTTOPAY_BASE_URL']}v1.0.1/#{parsed_request['responseData']['endpointUrl']}",
				signature_response: parsed_request['responseAuth']['signature'],
				signature_request: headers["Signature"]
			)

			Rails.logger.info "OTTOPAY RESPONSE ============================================="
			Rails.logger.info parsed_request
			Rails.logger.info "END OF OTTOPAY RESPONSE============================================="

			data = "#{ENV["OTTOPAY_BASE_URL"]}v1.0.1/#{parsed_request["responseData"]["endpointUrl"]}"
		end

		def generate_body(order, callback_url, webhook_url)
			body = {
				"transactionDetails": {
					"merchantName": "#{ENV["OTTOPAY_MERCHANT_NAME"]}",
					"orderId": transaction_order.unique_code,
					"paymentMethodId": "0",
					"amount": transaction_order.ottopay_payment.total_amount,
					"currency": "IDR",
					"frontendUrl": callback_url,
					"backendUrl": webhook_url,
					"successUrl": callback_url
				},
				"customerDetails": {
					"firstName": transaction_order.order.customer.name,
					"lastName": "",
					"email": transaction_order.order.customer.email,
					"phone": transaction_order.order.customer.phone_number
				}
			}
		end

		def generate_headers(body)
			timestamp = Time.now.to_i.to_s
			{
				"Timestamp": timestamp,
				"Signature": generate_signature(body, timestamp).to_s,
				"Authorization": authorization_header,
				"Content-Type": "application/json"
			}
		end

		def generate_signature(body, timestamp)
			trimmed_body = body.to_s.gsub(' :','').gsub('{:', '{').gsub('=>',':').gsub(/[^a-zA-Z0-9{}:.,]/i, '').downcase
			trimmed_body = "#{trimmed_body}&#{timestamp}&#{ENV["OTTOPAY_API_KEY"]}"
			OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha512"), ENV["OTTOPAY_API_KEY"], trimmed_body)
		end

		def authorization_header
			"Basic #{Base64.encode64(ENV["OTTOPAY_MERCHANT_ID"]).chomp}"
		end

	end
end