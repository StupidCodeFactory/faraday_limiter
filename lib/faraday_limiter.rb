require 'concurrent-edge'
require 'faraday_limiter/version'
require 'faraday_limiter/bucket'
require 'faraday_limiter/redis_bucket'
require 'faraday'

module FaradayLimiter
  class LimitReached < RuntimeError; end
  class WouldLimitReached < RuntimeError; end

  class Middleware < Faraday::Middleware

    DEFAULT_BUCKET_KEY = :default
    DEFAULT_REQUEST_COST = 1
    RESETS_AT_HEADER = 'FaradayLimiter-Resets-At'
    BUCKET_ID_HEADER = 'FaradayLimiter-Bucket-Id'

    def initialize(app, options = {})
      super(app)
      self.app        = app
      self.buckets    = options.fetch(:buckets) do
        RedisBucket.create_list(bucket_ids: [DEFAULT_BUCKET_KEY], interval: 1)
      end
    end

    def call(env)
      bucket_id   = env.request.context[:bucket_id] || DEFAULT_BUCKET_KEY
      request_cost = env.request.context && env.request.context[:request_cost] || DEFAULT_REQUEST_COST
      bucket = buckets[bucket_id]
      bucket.take(request_cost) do
        app.call(env).on_complete do |e|
          e.response_headers[RESETS_AT_HEADER] = bucket.resets_at
          e.response_headers[BUCKET_ID_HEADER] = bucket_id
        end
      end
    end

    private

    attr_accessor :app, :buckets

  end
end
