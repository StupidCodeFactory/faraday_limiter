RSpec.describe FaradayLimiter::Middleware do
  include ActiveSupport::Testing::TimeHelpers

  it 'has a version number' do
    expect(FaradayLimiter::VERSION).not_to be nil
  end

  describe '#call' do
    let(:request_limit) { 10 }
    let(:request_cost)  { 1 }
    let(:connection) do
      Faraday.new(url: 'http://localhost:3000') do |con|
        con.use described_class, limit: request_limit, interval: 10
        con.adapter :net_http
      end
    end

    def make_request
      connection.get('/limit_not_reached') do |req|
        req.options.context = { request_cost: request_cost }
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

    context 'when no buckets are provided' do
      context 'when the limit has not been reached' do
        before { stub_the_request }


        describe 'request' do
          context 'when not exceeding the request cost' do
            context 'when within the time limit' do

              it 'is allowed' do
                expect(make_request).to be_success
              end

            end

            context 'when past the time limit' do

              it 'is allowed' do
                expect(make_request).to be_success
              end

            end
          end

          context 'when exceeding the request cost' do
            let(:request_cost)  { 11 }

            it 'is not allowed' do
              expect { make_request }.to raise_error(FaradayLimiter::Bucket::WouldExceedLimit)
            end
          end
        end

        describe 'response' do
          it 'tracks the remaining response' do
            make_request
          end
        end

      end

      context 'when the limit has been reached' do
        let(:nowish) { Time.now.utc }

        before do
          stub_the_request
          request_limit.times { make_request }
        end

        context 'whitin the interval' do
          it { expect { make_request }.to raise_error(FaradayLimiter::Bucket::LimitExceeded) }
        end

        context 'when the interval has passed' do

          it 'allows the request' do
            travel_to nowish + 11 do
              expect(make_request).to be_success
            end
          end
        end
      end

    end

  end


end
