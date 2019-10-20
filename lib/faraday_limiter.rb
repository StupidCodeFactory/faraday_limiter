require 'singleton'
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

    def initialize(app, options = {})
      super(app)
      self.app        = app
      self.options    = options
      self.bucket_ids = options.fetch(:bucket_ids) { [DEFAULT_BUCKET_KEY] }
      raise ArgumentError if limit < bucket_ids.size
    end

    def call(env)
      bucket_id   = env.request.context[:bucket_id] || DEFAULT_BUCKET_KEY
      request_cost = env.request.context && env.request.context[:request_cost] || 1

      buckets[bucket_id].take(request_cost) { app.call(env) }
    end

    private

    attr_accessor :app, :options, :bucket_ids

    def buckets
      @buckets ||= begin
        register         = Concurrent::LazyRegister.new
        limit_per_bucket = (limit / bucket_ids.size.to_f).ceil
        tokens = Array.new(limit) { |i| i }

        bucket_ids.each do |bucket_id|
          bucket_limit = tokens.pop(limit_per_bucket).size
          register.add(bucket_id) { RedisBucket.new(bucket_id, bucket_limit, resets_at: (Time.now + interval).to_i) }
        end
        register
      end
    end

    def limit
      @limit ||= options[:limit]
    end

    def interval
      @interval ||= options[:interval]
    end
  end
end
