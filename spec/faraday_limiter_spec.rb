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
            'User-Agent'=>'Faraday v0.17.1'
          }).
        to_return(status: 200, body: {status: 200}.to_json, headers: {})
    end

    context 'when providing the buckets' do
      let(:nowish)        { Time.now }
      let(:bucket_one_id) { :bucket_one }
      let(:bucket_two_id) { :bucket_two }
      let(:bucket_ids)    { [bucket_one_id, bucket_two_id] }
      let(:buckets) do
        FaradayLimiter::RedisBucket.create_list(
          bucket_ids: bucket_ids,
          limit: request_limit,
          interval: interval
        )
      end
      let(:connection) do
        Faraday.new(url: 'http://localhost:3000') do |con|
          con.use described_class, buckets: buckets
          con.adapter :net_http
        end
      end
      let(:request_bucket_one_headers) { make_request(bucket_one_id).headers }
      let(:request_bucket_two_headers) { make_request(bucket_two_id).headers }

      around { |example| travel_to(nowish) { example.run } }

      before { stub_the_request }

      it "does something" do
        expect(request_bucket_one_headers).to include(
          described_class::RESETS_AT_HEADER => (nowish + interval).to_i,
          described_class::BUCKET_ID_HEADER => bucket_one_id,
        )
        expect(request_bucket_two_headers).to include(
          described_class::RESETS_AT_HEADER => (nowish + interval).to_i,
          described_class::BUCKET_ID_HEADER => bucket_two_id,
        )
      end
    end

  end
end
