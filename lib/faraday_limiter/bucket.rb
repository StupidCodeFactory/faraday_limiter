require 'monitor'

module FaradayLimiter
  class Bucket
    LimitError       = Class.new(RuntimeError)
    WouldExceedLimit = Class.new(LimitError)
    LimitExceeded    = Class.new(LimitError)

    def initialize(limit, interval)
      self.limit    = limit
      self.interval = interval
      self.lock    = Monitor.new
    end

    def take(request_cost, &block)
      reset_if_interval_exceeded

      raise LimitExceeded    if limit_exceeded?(request_cost)
      raise WouldExceedLimit if would_limit_exceeded?(request_cost)

      result = nil

      lock.synchronize do
        result = yield

        self.requests_left = requests_left - request_cost
      end

      result
    end

    def requests_left
      @requests_left ||= limit
    end

    private

    attr_accessor :limit, :interval, :lock
    attr_writer :requests_left, :started_at

    def would_limit_exceeded?(request_cost)
      lock.synchronize { request_cost > requests_left }
    end

    def limit_exceeded?(request_cost)
      lock.synchronize { requests_left <= 0 }
    end

    def reset_if_interval_exceeded
      lock.synchronize do
        return unless started_at + interval <= Time.now.utc

        self.started_at    = Time.now.utc
        self.requests_left = limit
      end
    end

    def started_at
      @started_at ||= Time.now.utc
    end

  end
end
