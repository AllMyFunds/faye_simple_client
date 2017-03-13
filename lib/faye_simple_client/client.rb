require "faraday"
require "faraday_middleware"

module FayeSimpleClient
  class CustomError < StandardError; end
  class Client

    MAX_ATTEMPTS = 10

    class << self
      attr_accessor :endpoint, :secret

      def client
        @client ||= new(endpoint, secret)
      end

      def push(channel, data)
        client.push(channel, data)
      end

      def subscriber_count(channel)
        client.subscriber_count(channel)
      end
    end

    attr_reader :endpoint, :secret

    def initialize(endpoint, secret)
      @endpoint = endpoint
      @secret = secret
    end

    def http
      @http ||= Faraday.new(url: endpoint) do |c|
        c.request :json
        c.request :basic_auth, "x", secret
        c.response :json, content_type: /\bjson$/
        c.adapter Faraday.default_adapter
      end
    end

    def push(channel, data)
      attempts = 0
      begin
        response = http.post(nil, {
          channel: channel,
          data:    data,
          ext:    { password: secret }
        })
        raise CustomError.new("Response body should not be empty") if response.body == ""
        errors = response.body.inject([]) do |result, e|
          result << e['error'] unless e['successful']
          result
        end
        if errors.present?
          raise CustomError.new(errors.compact.uniq.join(', '))
        end
        response
      rescue CustomError => error
        attempts += 1
        if attempts < MAX_ATTEMPTS
          sleep 0.1 * (attempts - 1) * 5
          retry
        else
          raise error
        end
      end
    end

    def subscriber_count(channel)
      response = http.get("/api/subscriber_count/#{channel.gsub(/^\//, "")}")
      response.body.to_i
    end

  end
end
