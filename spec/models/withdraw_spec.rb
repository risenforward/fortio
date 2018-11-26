# encoding: UTF-8
# frozen_string_literal: true

describe Withdraw do
  describe '#fix_precision' do
    it 'should round down to max precision' do
      withdraw = create(:btc_withdraw, sum: '0.123456789')
      expect(withdraw.sum).to eq('0.12345678'.to_d)
    end
  end

  context 'bank withdraw' do
    describe '#audit!' do
      subject { create(:usd_withdraw) }
      before  { subject.submit! }

      it 'should accept withdraw with clean history' do
        subject.audit!
        expect(subject).to be_accepted
      end

      it 'should accept quick withdraw directly' do
        subject.update_attributes sum: 5
        subject.audit!
        expect(subject).to be_accepted
      end
    end
  end

  context 'coin withdraw' do
    describe '#audit!' do
      subject { create(:btc_withdraw, sum: sum) }
      let(:sum) { 10.to_d }
      before { subject.submit! }

      it 'should be rejected if address is invalid' do
        WalletClient.stubs(:[]).returns(mock('rpc', inspect_address!: { is_valid: false }))
        subject.audit!
        expect(subject).to be_rejected
      end

      context 'internal recipient' do
        let(:payment_address) { create(:btc_payment_address) }
        subject { create(:btc_withdraw, rid: payment_address.address) }

        around do |example|
          WebMock.disable_net_connect!
          example.run
          WebMock.allow_net_connect!
        end

        let :request_body do
          { jsonrpc: '1.0',
            method:  'validateaddress',
            params:  [payment_address.address]
          }.to_json
        end

        let(:response_body) { '{"result":{"isvalid":true,"ismine":true}}' }

        before do
          stub_request(:post, 'http://127.0.0.1:18332').with(body: request_body).to_return(body: response_body)
        end

        it 'permits withdraw to address which belongs to Peatio' do
          subject.audit!
          expect(subject).to be_accepted
        end
      end

      it 'should accept withdraw with clean history' do
        WalletClient.stubs(:[]).returns(mock('rpc', inspect_address!: { is_valid: true }))
        subject.audit!
        expect(subject).to be_accepted
      end

      context 'sum less than quick withdraw limit' do
        let(:sum) { '0.099'.to_d }
        it 'should approve quick withdraw directly' do
          WalletClient.stubs(:[]).returns(mock('rpc', inspect_address!: { is_valid: true }))
          subject.audit!
          expect(subject).to be_processing
        end
      end
    end

    describe 'account id assignment' do
      subject { build :btc_withdraw, account_id: 999 }

      it 'don\'t accept account id from outside' do
        subject.save
        expect(subject.account_id).to eq(subject.member.get_account(subject.currency).id)
      end
    end
  end

  context 'Worker::WithdrawCoin#process' do
    subject { create(:btc_withdraw) }
    before do
      @rpc = mock
      @rpc.stubs(load_balance: 50_000, build_withdrawal!: '12345')

      subject.submit
      subject.accept
      subject.process
      subject.save!

    end

    it 'transitions to :failed after calling WalletService but getting Exception' do
      WalletService.stubs(:[]).raises(WalletService::Error)
      Worker::WithdrawCoin.new.process({ id: subject.id })

      expect(subject.reload.failed?).to be true
    end

    it 'transitions to :confirming after calling WalletService' do
      WalletService.stubs(:[]).returns(@rpc)

      Worker::WithdrawCoin.new.process({ id: subject.id })

      subject.reload
      expect(subject.confirming?).to be true
      expect(subject.txid).to eq('12345')
    end

    it 'does not send coins again if previous attempt failed' do
      WalletService.stubs(:[]).raises(NameError)
      begin Worker::WithdrawCoin.new.process({ id: subject.id }); rescue; end
      WalletService.stubs(:[]).returns(WalletService::Bitcoind)

      expect { Worker::WithdrawCoin.new.process({ id: subject.id }) }.to_not change { subject.account.reload.amount }
      expect(subject.reload.failed?).to be true
    end

    it 'unlocks coins after calling rpc but getting Exception' do
      WalletService.stubs(:[]).raises(NameError)

      expect { Worker::WithdrawCoin.new.process({ id: subject.id }) }
          .to change { subject.account.reload.locked }.by(-subject.sum)
          .and change { subject.account.reload.balance }.by(subject.sum)
    end
  end

  context 'aasm_state' do
    subject { create(:new_usd_withdraw, :with_deposit_liability, sum: 1000) }

    before do
      subject.stubs(:send_withdraw_confirm_email)
    end

    it 'initializes with state :prepared' do
      expect(subject.prepared?).to be true
    end

    it 'transitions to :rejected after calling #reject!' do
      subject.submit!
      subject.reject!

      expect(subject.rejected?).to be true
    end

    context :submit do
      it 'transitions to :submitted after calling #submit!' do
        subject.submit!
        expect(subject.submitted?).to be true
        expect(subject.sum).to eq subject.account.locked
      end

      context :record_submit_operations! do
        it 'creates two liability operations' do
          expect{ subject.submit! }.to change{ Operations::Liability.count }.by(2)
        end

        it 'doesn\'t create asset operations' do
          expect{ subject.submit! }.to_not change{ Operations::Asset.count }
        end

        it 'debits main liabilities for member' do
          expect{ subject.submit! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :main)
          }.by(-subject.sum)
        end

        it 'credits locked liabilities for member' do
          expect{ subject.submit! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :locked)
          }.by(subject.sum)
        end

        it 'updates both legacy and operations based member balance' do
          subject.submit!

          %i[main locked].each do |kind|
            expect(
              subject.member.balance_for(currency: subject.currency, kind: kind)
            ).to eq(
              subject.member.legacy_balance_for(currency: subject.currency, kind: kind)
            )
          end
        end
      end
    end

    context :process do
      before { subject.submit! }
      before { subject.accept! }

      it 'transitions to :processing after calling #process! when withdrawing fiat currency' do
        subject.stubs(:coin?).returns(false)

        subject.process!

        expect(subject.processing?).to be true
      end

      it 'transitions to :failed after calling #fail! when withdrawing fiat currency' do
        subject.stubs(:coin?).returns(false)

        subject.process!

        expect { subject.fail! }.to_not change { subject.account.amount }

        expect(subject.failed?).to be true
      end

      it 'transitions to :processing after calling #process!' do
        subject.expects(:send_coins!)

        subject.process!

        expect(subject.processing?).to be true
      end
    end

    context :cancel do
      it 'transitions to :canceled after calling #cancel!' do
        subject.cancel!

        expect(subject.canceled?).to be true
      end

      it 'transitions from :submitted to :canceled after calling #cancel!' do
        subject.submit!
        subject.cancel!

        expect(subject.canceled?).to be true
      end

      it 'transitions from :accepted to :canceled after calling #cancel!' do
        subject.submit!
        subject.accept!
        subject.cancel!

        expect(subject.canceled?).to be true
      end

      context :record_cancel_operations do
        before do
          subject.submit!
          subject.accept!
        end
        it 'creates two liability operations' do
          expect{ subject.cancel! }.to change{ Operations::Liability.count }.by(2)
        end

        it 'doesn\'t create asset operations' do
          expect{ subject.cancel! }.to_not change{ Operations::Asset.count }
        end

        it 'credits main liabilities for member' do
          expect{ subject.cancel! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :main)
          }.by(subject.sum)
        end

        it 'debits locked liabilities for member' do
          expect{ subject.cancel! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :locked)
          }.by(-subject.sum)
        end

        it 'updates both legacy and operations based member balance' do
          subject.cancel!

          %i[main locked].each do |kind|
            expect(
              subject.member.balance_for(currency: subject.currency, kind: kind)
            ).to eq(
              subject.member.legacy_balance_for(currency: subject.currency, kind: kind)
            )
          end
        end
      end
    end

    context :suspect do
      before do
        subject.submit!
      end

      it 'transitions from :submitted to :suspected after calling #suspect!' do
        subject.suspect!

        expect(subject.suspected?).to be true
      end

      context :record_cancel_operations do

        it 'creates two liability operations' do
          expect{ subject.suspect! }.to change{ Operations::Liability.count }.by(2)
        end

        it 'doesn\'t create asset operations' do
          expect{ subject.suspect! }.to_not change{ Operations::Asset.count }
        end

        it 'credits main liabilities for member' do
          expect{ subject.suspect! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :main)
          }.by(subject.sum)
        end

        it 'debits locked liabilities for member' do
          expect{ subject.suspect! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :locked)
          }.by(-subject.sum)
        end

        it 'updates both legacy and operations based member balance' do
          subject.suspect!

          %i[main locked].each do |kind|
            expect(
              subject.member.balance_for(currency: subject.currency, kind: kind)
            ).to eq(
              subject.member.legacy_balance_for(currency: subject.currency, kind: kind)
            )
          end
        end
      end
    end

    context :reject do
      before do
        subject.submit!
      end

      it 'transitions from :submitted to :rejected after calling #reject!' do
        subject.reject!
        expect(subject.rejected?).to be true
      end

      it 'transitions from :accepted to :rejected after calling #reject!' do
        subject.accept!
        subject.reject!

        expect(subject.rejected?).to be true
      end

      context :record_cancel_operations do

        it 'creates two liability operations' do
          expect{ subject.reject! }.to change{ Operations::Liability.count }.by(2)
        end

        it 'doesn\'t create asset operations' do
          expect{ subject.reject! }.to_not change{ Operations::Asset.count }
        end

        it 'credits main liabilities for member' do
          expect{ subject.reject! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :main)
          }.by(subject.sum)
        end

        it 'debits locked liabilities for member' do
          expect{ subject.reject! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :locked)
          }.by(-subject.sum)
        end

        it 'updates both legacy and operations based member balance' do
          subject.reject!

          %i[main locked].each do |kind|
            expect(
              subject.member.balance_for(currency: subject.currency, kind: kind)
            ).to eq(
              subject.member.legacy_balance_for(currency: subject.currency, kind: kind)
            )
          end
        end
      end
    end

    context :success do

      before do
        subject.submit!
        subject.accept!
        subject.process!
        subject.dispatch!
      end

      it 'transitions from :confirming to :success after calling #success!' do
        subject.success!

        expect(subject.succeed?).to be true
      end

      context :record_complete_operations do

        it 'creates single liability operation' do
          expect{ subject.success! }.to change{ Operations::Liability.count }.by(1)
        end

        it 'creates asset operation' do
          expect{ subject.success! }.to change{ Operations::Asset.count }.by(1)
        end

        it 'doesn\'t change main liability balance for member' do
          expect{ subject.success! }.to_not change {
            subject.member.balance_for(currency: subject.currency, kind: :main)
          }
        end

        it 'debits locked liabilities for member' do
          expect{ subject.success! }.to change {
            subject.member.balance_for(currency: subject.currency, kind: :locked)
          }.by(-subject.sum)
        end

        it 'updates both legacy and operations based member balance' do
          subject.success!

          %i[main locked].each do |kind|
            expect(
              subject.member.balance_for(currency: subject.currency, kind: kind)
            ).to eq(
              subject.member.legacy_balance_for(currency: subject.currency, kind: kind)
            )
          end
        end

        it 'credits revenues' do
          expect{ subject.success! }.to change {
            Operations::Revenue.balance(currency: subject.currency)
          }.by(subject.fee)
        end
      end
    end
  end

  context '#quick?' do

    before do
      withdraw.currency.update(
        'withdraw_limit_24h': 1,
        'withdraw_limit_72h': 3
      )
    end

    context 'returns false if exceeds 24h withdraw limit' do
      subject(:withdraw) { create(:btc_withdraw, sum: 2, aasm_state: 'accepted') }
      it { expect(withdraw).to_not be_quick }
    end

    context 'returns false if exceeds 72h withdraw limit' do
      subject(:withdraw) { create(:btc_withdraw, sum: 4, aasm_state: 'accepted') }
      it { expect(withdraw).to_not be_quick }
    end

    context 'returns true if doesn\'t exceeds 24h withdraw limit' do
      subject(:withdraw) { create(:btc_withdraw, sum: 0.5, aasm_state: 'accepted') }
      it { expect(withdraw).to be_quick }
    end

    context 'returns false if exceeds 24h withdraw limit' do
      subject(:withdraw) { create(:btc_withdraw, sum: 0.5, aasm_state: 'accepted') }
      it do
        second_withdraw = create(:btc_withdraw, member: withdraw.member, sum: 0.8, aasm_state: 'accepted')
        second_withdraw.process!
        expect(second_withdraw).to_not be_quick
      end
    end
  end

  context 'fee is set to fixed value of 10' do
    let(:withdraw) { create(:usd_withdraw, sum: 200) }
    before { Currency.any_instance.expects(:withdraw_fee).once.returns(10) }
    it 'computes fee' do
      expect(withdraw.fee).to eql 10.to_d
      expect(withdraw.amount).to eql 190.to_d
    end
  end

  context 'fee exceeds amount' do
    let(:withdraw) { build(:usd_withdraw, sum: 200) }
    before { Currency.any_instance.expects(:withdraw_fee).once.returns(200) }
    it 'fails validation' do
      expect(withdraw.save).to eq false
      expect(withdraw.errors.full_messages).to include 'Amount must be greater than 0.0'
    end
  end

  it 'automatically generates TID if it is blank' do
    expect(create(:btc_withdraw).tid).not_to be_blank
  end

  it 'doesn\'t generate TID if it is not blank' do
    expect(create(:btc_withdraw, tid: 'TID1234567890xyz').tid).to eq 'TID1234567890xyz'
  end

  it 'validates uniqueness of TID' do
    record1 = create(:btc_withdraw)
    record2 = build(:btc_withdraw, tid: record1.tid)
    record2.save
    expect(record2.errors.full_messages.first).to match(/tid has already been taken/i)
  end

  it 'uppercases TID' do
    record = create(:btc_withdraw)
    expect(record.tid).to eq record.tid.upcase
  end

  context 'CashAddr' do
    let(:member) { create(:member) }
    let(:account) { member.ac(:bch).tap { |x| x.update!(balance: 1.0.to_d) } }
    let :record do
      Withdraws::Coin.new \
        currency: Currency.find(:bch),
        member:   member,
        rid:      address,
        sum:      1.0.to_d,
        account:  account
    end

    context 'valid CashAddr address' do
      let(:address) { 'bitcoincash:qqkv9wr69ry2p9l53lxp635va4h86wv435995w8p2h' }
      it { expect(record.save).to eq true }
    end

    context 'invalid CashAddr address' do
      let(:address) { 'bitcoincash::qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a' }
      it do
        expect(record.save).to eq false
        expect(record.errors.full_messages).to include 'Rid is invalid'
      end
    end

    context 'valid legacy address' do
      let(:address) { '155fzsEBHy9Ri2bMQ8uuuR3tv1YzcDywd4' }
      it { expect(record.save).to eq true }
    end

    context 'invalid legacy address' do
      let(:address) { '155fzsEBHy9Ri2bMQ8uuuR3tv1YzcDywd400' }
      it do
        expect(record.save).to eq false
        expect(record.errors.full_messages).to include 'Rid is invalid'
      end
    end
  end

  it 'doesn\'t raise exceptions in before_validation callbacks if member doesn\'t exist' do
    expect { Withdraw.new.validate }.not_to raise_error
  end

  it 'doesn\'t raise exceptions in before_validation callbacks if currency doesn\'t exist' do
    expect { Withdraw.new(member: create(:member)).validate }.not_to raise_error
  end
end
