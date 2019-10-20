RSpec.describe FaradayLimiter::Middleware do
  include ActiveSupport::Testing::TimeHelpers

  it 'has a version number' do
    expect(FaradayLimiter::VERSION).not_to be nil
  end

  describe '#call' do
    let(:request_limit) { 10 }
    let(:request_cost)  { 1 }
    let(:interval)      { 10 }
    let(:connection) do
      Faraday.new(url: 'http://localhost:3000') do |con|
        con.use described_class, limit: request_limit, interval: interval
        con.adapter :net_http
      end
    end

    def make_request(bucket_id = described_class::DEFAULT_BUCKET_KEY)
      connection.get('/limit_not_reached') do |req|
        req.options.context = { request_cost: request_cost, bucket_id: bucket_id }
      end
    end

    def stub_the_request
      stub_request(:get, "http://localhost:3000/limit_not_reached").
        with(
          headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent'=>'Faraday v0.17.0'
          }).
        to_return(status: 200, body: "", headers: {})
    end


    describe 'bucket configuration' do
      let(:redis) { Redis.new }
      let(:bucket_one) { instance_double(FaradayLimiter::RedisBucket) }
      let(:nowish)       { Time.now }

      before do
        redis.del(described_class::DEFAULT_BUCKET_KEY)
      end

      context 'when no bucket_ids specified' do

        before { stub_the_request }

        it 'uses the default' do
          travel_to nowish do
            expect(FaradayLimiter::RedisBucket)
              .to receive(:new)
                    .with(described_class::DEFAULT_BUCKET_KEY, request_limit, resets_at: (nowish + interval).to_i)
                    .and_return(bucket_one)
            expect(bucket_one).to receive(:take).with(request_cost).and_yield

            make_request
          end
        end
      end

      context 'when bucket_ids are specified' do
        let(:bucket_one_id) { :bucket_one }
        let(:bucket_two_id) { :bucket_two }
        let(:bucket_two)    { instance_double(FaradayLimiter::RedisBucket) }
        let(:bucket_ids)    { [bucket_one_id, bucket_two_id] }

        let(:connection) do
          Faraday.new(url: 'http://localhost:3000') do |con|
            con.use described_class, limit: request_limit, interval: interval, bucket_ids: bucket_ids
            con.adapter :net_http
          end
        end

        before do
          stub_the_request
          redis.del(bucket_one_id)
          redis.del(bucket_two_id)
        end

        it 'configures the appropriate amout of requests per bucket' do
          travel_to nowish do
            expect(FaradayLimiter::RedisBucket)
              .to receive(:new)
                    .with(
                      bucket_one_id,
                      request_limit / bucket_ids.size,
                      resets_at: (nowish + interval).to_i)
                    .and_return(bucket_one)
            expect(FaradayLimiter::RedisBucket).not_to receive(:new).with(any_args)

            expect(bucket_one).to receive(:take).with(request_cost).and_yield
            expect(bucket_two).not_to receive(:take).with(request_cost).and_yield

            make_request(bucket_one_id)
          end
        end

        describe 'when limit is smaller than bucket store' do
          let(:request_limit) { 1 }

          it { expect { make_request(bucket_one_id) }.to raise_error(ArgumentError) }
        end

        describe 'when limit is smaller than bucket store' do
          let(:request_limit) { 3 }
          let(:expected_allowed_tokens) { 1 }

          it 'configures the last buckets with less tokens' do
            travel_to nowish do
              expect(FaradayLimiter::RedisBucket)
                .to receive(:new)
                      .with(
                        bucket_two_id,
                        expected_allowed_tokens,
                        resets_at: (nowish + interval).to_i)
                      .and_return(bucket_two)
              expect(bucket_two).to receive(:take).with(request_cost).and_yield

              make_request(bucket_two_id)
            end
          end
        end
      end
    end
  end
end
