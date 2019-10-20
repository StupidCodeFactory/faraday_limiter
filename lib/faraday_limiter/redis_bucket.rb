require 'redis'

module FaradayLimiter

  LimitError            = Class.new(RuntimeError)
  ReachedBucketLimit    = Class.new(LimitError)
  WouldReachBucketLimit = Class.new(RuntimeError)

  class RedisBucket

    ZCARD_RESULT_INDEX = 0

    attr_accessor :resets_in, :resets_at

    def initialize(bucket_id, limit, resets_at: (Time.now + 60).to_i)
      self.bucket_id  = bucket_id
      self.limit      = limit
      self.resets_at  = resets_at
    end

    def take(request_cost = 1, &block)
      key = Time.now.to_i
      expire_in = nil
      results = redis.multi do |c|
        c.zcard(bucket_id)
        request_cost.times { c.zadd(bucket_id, key, SecureRandom.uuid) }
        expire_in = resets_at - Time.now.to_i
        c.expire(bucket_id, expire_in)
      end

      current_windown_request_count = results[ZCARD_RESULT_INDEX]

      if current_windown_request_count >= limit
        raise ReachedBucketLimit
      elsif (current_windown_request_count + request_cost) > limit
        raise WouldReachBucketLimit
      else
        yield
      end

    end

    def reset
      redis.del(bucket_id)
    end

    private

    attr_accessor :bucket_id, :limit

    def redis
      @redis ||= Redis.new
    end
  end
end
