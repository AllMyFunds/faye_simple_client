module FayeSimpleClient
  class CustomError < StandardError; end
  class Client
    class << self
      attr_accessor :endpoint, :secret

      def client
        @client ||= Faraday.new  url: endpoint do |c|
          c.request :json
          c.response :json, content_type: /\bjson$/
          c.adapter Faraday.default_adapter
        end
      end

      def push(channel, data)
        response = client.post(nil, {
          channel: channel,
          data:    data,
          ext:    { password: secret }
        })
        errors = response.body.inject([]) do |result, e|
          result << e['error'] unless e['successful']
          result
        end
        if errors.present?
          raise CustomError.new(errors.compact.uniq.join(', '))
        end
        response
      end
    end
  end
end
