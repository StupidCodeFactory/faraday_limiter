require 'faraday_limiter/version'
require 'faraday'

module FaradayLimiter
  class LimitReached < RuntimeError; end
  class WouldLimitReached < RuntimeError; end

  class Middleware < Faraday::Middleware

    def initialize(app, options = {})
      super(app)
      self.app = app
      self.options = options
    end

    def call(env)
      request_cost = env.request.context && env.request.context[:request_cost] || 1
      reset_limits

      if limit_exceeded?
        raise LimitReached
      elsif request_would_exceed_limit?(request_cost)
        raise WouldLimitReached
      else
        self.limit = limit - request_cost
        app.call(env)
      end

    end

    private

    attr_accessor :app, :options
    attr_writer :limit, :started_at

    def reset_limits
      return unless started_at + interval <= Time.now.utc

      self.started_at = Time.now.utc
      self.limit = options[:limit]
    end

    def limit_exceeded?
      limit <= 0
    end

    def request_would_exceed_limit?(request_cost)
      limit < request_cost
    end

    def limit
      @limit ||= options[:limit]
    end

    def interval
      @interval ||= options[:interval]
    end

    def started_at
      @started_at ||= Time.now.utc
    end
  end
end
