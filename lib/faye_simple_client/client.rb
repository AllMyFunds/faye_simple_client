require "faraday"
require "faraday_connection_pool"
require "faraday_middleware"

module FayeSimpleClient
  class CustomError < StandardError; end
  class ServerError < Faraday::Error::ClientError; end

  FaradayConnectionPool.configure do |config|
    config.size = 10
    config.pool_timeout = 5
    config.keep_alive_timeout = 30
  end

  class RaiseServerError < Faraday::Middleware
    ServerErrorStatuses = 500...600
    MissingStatus = 404

    def call(env)
      response = @app.call(env)
      case env[:status]
      when ServerErrorStatuses
        raise ServerError, response_values(env)
      when MissingStatus
        raise ServerError, response_values(env)
      end
      response
    end

    def response_values(env)
      {:status => env.status, :headers => env.response_headers, :body => env.body}
    end

    Faraday::Request.register_middleware raise_server_error: -> { self }
  end

  class Client

    MAX_ATTEMPTS = 30

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
        c.response :json, content_type: /\bjson$/
        c.request :json
        c.request :basic_auth, "x", secret
        c.request :retry, max: MAX_ATTEMPTS,
                          interval: 0.05,
                          interval_randomness: 0.5,
                          backoff_factor: 2,
                          methods: [:post, :delete, :get, :head, :options, :put],
                          exceptions: [ Faraday::Error::ConnectionFailed, ServerError ]
        c.request :raise_server_error
        c.adapter :net_http_pooled
      end
    end

    def push(channel, data)
      response = http.post(nil, {
        channel: channel,
        data:    data,
        ext:    { password: secret }
      })
      errors = response.body.inject([]) do |result, e|
        result << e['error'] unless e['successful']
        result
      end
      if errors && errors.is_a?(Array) && errors.size > 0
        raise CustomError.new(errors.compact.uniq.join(', '))
      end
      response
    end

    def subscriber_count(channel)
      response = http.get("api/subscriber_count/#{channel.gsub(/^\//, "")}")
      if response.status == 200
        response.body.to_i
      else
        -1
      end
    end

  end
end
