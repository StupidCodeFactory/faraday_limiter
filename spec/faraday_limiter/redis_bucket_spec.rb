require 'spec_helper'

RSpec.describe FaradayLimiter::RedisBucket do
  include ActiveSupport::Testing::TimeHelpers

  subject(:bucket) { described_class.new(bucket_id, limit, resets_at: resets_at.to_i) }

  let(:bucket_id)    { :bucket_id }
  let(:limit)        { 10 }
  let(:nowish)       { Time.now }
  let(:resets_at)    { Time.now + 60 }
  let(:request_cost) { 1 }

  before do
    subject.reset
  end

  describe '.create' do
    let(:interval)      { 60 }
    let(:bucket_one_id) { :bucket_one_id }
    let(:bucket_two_id) { :bucket_two_id }
    let(:bucket_ids)    { [bucket_one_id, bucket_two_id] }
    let(:buckets)       { described_class.create_list(limit: limit, interval: interval, bucket_ids: bucket_ids) }
    let(:bucket_one)    { instance_double(described_class) }
    let(:bucket_two)    { instance_double(described_class) }
    let(:nowish)        { Time.now }

    around { |example| travel_to(nowish) { example.run } }

    it 'returns a concurrent lazy register has bucket list' do
      expect(FaradayLimiter::RedisBucket)
        .to receive(:new).with(bucket_one_id, limit / 2, resets_at: (nowish + interval).to_i)
        .and_return(bucket_one)
      expect(FaradayLimiter::RedisBucket)
        .to receive(:new).with(bucket_two_id, limit / 2, resets_at: (nowish + interval).to_i)
        .and_return(bucket_two)

      expect(buckets[:bucket_one_id]).to eq(bucket_one)
      expect(buckets[:bucket_two_id]).to eq(bucket_two)
    end
  end

  describe '#take' do

    context 'when the current window time has not been exceeded' do
      context 'when the rate limit has not been exceeded' do
        context 'when not exceeding the request cost' do
          it "yields the block" do
            expect { |b| subject.take(request_cost, &b) }.to yield_with_no_args
          end
        end

        context 'when exceeding the request cost' do
          before do
            (limit - 1).times { subject.take(request_cost, &lambda {}) }
          end

          it { expect { subject.take(2, &lambda {}) }
                 .to raise_error(
                       FaradayLimiter::WouldReachBucketLimit,
                       '{"current_windown_request_count":9,"limit":10,"requested":2}'
                     )
          }
        end
      end

      context 'when the request cost would be exceeded' do
        before do
          limit.times { subject.take(request_cost, &lambda {}) }
        end

        it { expect { subject.take(request_cost, &lambda {}) }.to raise_error(FaradayLimiter::ReachedBucketLimit) }
      end
    end

    context 'when the current window time has been exceeded' do
      context 'when the rate limit was reached' do
        let(:resets_at) { Time.now + 1 }
        before { limit.times { subject.take(request_cost, &lambda {}) } }

        it 'allows the request'do
          sleep 1.1
          expect { subject.take(request_cost, &lambda {}) }.not_to raise_error
        end

        context 'when the request cost would exceed the limit' do
          it {
            sleep 1.1
            expect { subject.take(11, &lambda {}) }.to raise_error(FaradayLimiter::WouldReachBucketLimit)
          }
        end
      end
    end
  end
end
