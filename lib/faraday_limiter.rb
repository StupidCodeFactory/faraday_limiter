require 'singleton'
require 'concurrent-edge'
require 'faraday_limiter/version'
require 'faraday_limiter/bucket'
require 'faraday'

module FaradayLimiter
  class LimitReached < RuntimeError; end
  class WouldLimitReached < RuntimeError; end

  class Middleware < Faraday::Middleware

    DEFAULT_BUCKET_KEY = :default

    def initialize(app, options = {})
      super(app)
      self.app     = app
      self.options = options
      self.buckets = Concurrent::LazyRegister.new
      bucket_ids = options.fetch(:bucket_ids) { [DEFAULT_BUCKET_KEY] }

      limit_per_bucket = limit / bucket_ids.size

      bucket_ids.each do |bucket_id|
        buckets.add(bucket_id) { Bucket.new(limit_per_bucket, interval) }
      end
    end

    def call(env)
      bucket_key   = env.request.context[:bucket_key] || DEFAULT_BUCKET_KEY
      request_cost = env.request.context && env.request.context[:request_cost] || 1

      buckets[bucket_key].take(request_cost) { app.call(env) }
    end

    private

    attr_accessor :app, :options, :buckets

    def limit
      @limit ||= options[:limit]
    end

    def interval
      @interval ||= options[:interval]
    end
  end
end
