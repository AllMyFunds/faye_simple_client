require "faraday"
require "faraday_middleware"

module FayeSimpleClient
  class CustomError < StandardError; end
  class EmptyBody < StandardError; end

  class EmptyBodyMiddleware < Faraday::Response::Middleware
    def on_complete(env)
      if env[:status] == 200 && env[:body].to_s == ""
        raise EmptyBody.new("Body empty")
      end
    end
  end

  class Client

    MAX_ATTEMPTS = 20

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
        c.request :retry, max: MAX_ATTEMPTS,
                          interval: 0.05,
                          interval_randomness: 0.5,
                          backoff_factor: 2,
                          exceptions: [ Faraday::Error::ConnectionFailed, EmptyBody ]
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

    def subscriber_count(channel)
      response = http.get("/api/subscriber_count/#{channel.gsub(/^\//, "")}")
      response.body.to_i
    end

  end
end
