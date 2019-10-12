require 'faraday_limiter/bucket'

RSpec.describe FaradayLimiter::Bucket do

  include ActiveSupport::Testing::TimeHelpers

  let(:limit)    { 10 }
  let(:interval) { 10 }
  let(:nowish) { Time.now.utc }

  subject { described_class.new(limit, interval) }

  describe '#take' do
    let(:request_cost) { 10 }

    context 'when the request cost does not exceed the limit' do
      context 'when within the interval' do
        it 'yields the block' do
          expect { |block| subject.take(request_cost, &block) }.to yield_with_no_args
        end
      end

      context 'when not within the interval' do


        it 'yields the block' do
          travel_to nowish + 11 do
            expect { |block| subject.take(request_cost, &block) }.to yield_with_no_args
          end
        end
      end
    end

    context 'when the request cost does exceed the limit' do
      let(:request_cost) { 11 }

      context 'when within the interval' do
        it { expect { subject.take(request_cost) }.to raise_error(described_class::WouldExceedLimit) }
      end

      context 'when not within the interval' do

        it 'yields the block' do
          travel_to nowish + 11 do
            expect { subject.take(request_cost) }.to raise_error(described_class::WouldExceedLimit)
          end
        end
      end
    end

    context 'when the limit has been reached' do

      before { subject.take(10) {} }

      it { expect { subject.take(1) }.to raise_error(described_class::LimitExceeded) }
    end
  end

end
