require 'json'
require 'redis'

module FaradayLimiter

  LimitError            = Class.new(RuntimeError)
  ReachedBucketLimit    = Class.new(LimitError)
  WouldReachBucketLimit = Class.new(RuntimeError)

  class RedisBucket

    ZCARD_RESULT_INDEX = 0

    DEFAULT_INTERVAL = 86_400
    DEFAULT_LIMIT = 1000


    attr_accessor :resets_in, :resets_at

    def self.create_list(bucket_ids:, limit: DEFAULT_LIMIT, interval: DEFAULT_INTERVAL)
      register = Concurrent::LazyRegister.new
      limit_per_bucket = (limit / bucket_ids.size.to_f).ceil
      tokens = Array.new(limit) { |i| i }


      bucket_ids.each do |bucket_id|
        bucket_limit = tokens.pop(limit_per_bucket).size
        register.add(bucket_id) do
          FaradayLimiter::RedisBucket.new(bucket_id, bucket_limit, resets_at: (Time.now + interval).to_i)
        end
      end
      register
    end


    def initialize(id, limit, resets_at: (Time.now + 60).to_i)
      self.id        = id
      self.limit     = limit
      self.resets_at = resets_at
    end

    def take(request_cost = 1, &block)
      key = Time.now.to_i
      expire_in = nil
      results = redis.multi do |c|
        c.zcard(id)
        request_cost.times { c.zadd(id, key, SecureRandom.uuid) }
        expire_in = resets_at - Time.now.to_i
        c.expire(id, expire_in)
      end

      current_windown_request_count = results[ZCARD_RESULT_INDEX]

      if current_windown_request_count >= limit
        raise ReachedBucketLimit
      elsif (current_windown_request_count + request_cost) > limit
        message = {
          current_windown_request_count: current_windown_request_count,
          limit: limit,
          requested: request_cost
        }
        raise WouldReachBucketLimit, JSON.generate(message)
      else
        yield
      end

    end

    def reset
      redis.del(id)
    end

    private

    attr_accessor :id, :limit

    def redis
      @redis ||= Redis.new
    end
  end
end
