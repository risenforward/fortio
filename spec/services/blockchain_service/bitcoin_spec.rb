# encoding: UTF-8
# frozen_string_literal: true

describe BlockchainService::Bitcoin do

  around do |example|
    WebMock.disable_net_connect!
    example.run
    WebMock.allow_net_connect!
  end

  describe 'BlockchainClient::Bitcoin' do
    let(:block_data) do
      Rails.root.join('spec', 'resources', 'bitcoin-data', block_file_name)
        .yield_self { |file_path| File.open(file_path) }
        .yield_self { |file| JSON.load(file) }
    end

    let(:start_block)   { block_data.first['result']['height'] }
    let(:latest_block)  { block_data.last['result']['height'] }

    let(:blockchain) do
      Blockchain.find_by_key('btc-testnet')
        .tap { |b| b.update(height: start_block) }
    end

    let(:client) { BlockchainClient[blockchain.key] }

    def request_block_hash_body(block_height)
      { jsonrpc: '1.0',
        method: :getblockhash,
        params:  [block_height]
      }.to_json
    end

    def request_block_body(block_hash)
      { jsonrpc: '1.0',
        method:  :getblock,
        params:  [block_hash, 2]
      }.to_json
    end

    context 'two BTC deposit was created during blockchain proccessing' do
      # File with real json rpc data for two blocks.
      let(:block_file_name) { '1354419-1354420.json' }

      let(:expected_deposits) do
        [
          {
            amount:   1.30000000,
            address:  '2MvCSzoFbQsVCTjN2rKWPuHa3THXSp1mHWt',
            txid:     '68ecb040b8d9716c1c09d552e158f69ba9b4b2bbbfb8407bef348f78e1eabbe8'
          },
          {
            amount:   0.65000000,
            address:  '2MvCSzoFbQsVCTjN2rKWPuHa3THXSp1mHWt',
            txid:     '76b0e88cdb624d3d10122c6dfcb75c379df0f4faf27cb4dbb848ea560dd611fa'
          }
        ]
      end

      let(:currency) { Currency.find_by_id(:btc) }

      let!(:payment_address) do
        create(:btc_payment_address, address: '2MvCSzoFbQsVCTjN2rKWPuHa3THXSp1mHWt')
      end

      before do
        # Mock requests and methods.
        client.class.any_instance.stubs(:latest_block_number).returns(latest_block)

        Deposits::Coin.where(currency: currency).delete_all

        block_data.each_with_index do |blk, index|
          # stub get_block_hash
          stub_request(:post, client.endpoint)
            .with(body: request_block_hash_body(blk['result']['height']))
            .to_return(body: {result: blk['result']['hash']}.to_json)

          # stub get_block
          stub_request(:post, client.endpoint)
            .with(body: request_block_body(blk['result']['hash']))
            .to_return(body: blk.to_json)
        end

        # Process blockchain data.
        BlockchainService[blockchain.key].process_blockchain(force: true)
      end

      subject { Deposits::Coin.where(currency: currency) }

      it 'creates two deposit' do
        expect(Deposits::Coin.where(currency: currency).count).to eq expected_deposits.count
      end

      it 'creates deposits with correct attributes' do
        expected_deposits.each do |expected_deposit|
          expect(subject.where(expected_deposit).count).to eq 1
        end
      end

      context 'we process same data one more time' do
        before do
          blockchain.update(height: start_block)
        end

        it 'doesn\'t change deposit' do
          expect(blockchain.height).to eq start_block
          expect{ BlockchainService[blockchain.key].process_blockchain(force: true)}.not_to change{subject}
        end
      end
    end

    context 'two BTC deposit in one transactions was created during blockchain proccessing' do
      # File with real json rpc data for two blocks.
      let(:block_file_name) { '1354419-1354420.json' }

      let(:expected_deposits) do
        [
          {
            amount:   0.09999834,
            address:  '2N53Qy2KPYc6FBboYpuQmYroiSu8S6xthug',
            txid:     '0274c3905b407d75ee26bf948d6d4365a6dd5f3941b0fdc281e8afa01580d67d'
          },
          {
            amount:   0.60000000,
            address:  '2N9ufFR59zrxPETBaxEH51PcxAeJ2TyASVm',
            txid:     '0274c3905b407d75ee26bf948d6d4365a6dd5f3941b0fdc281e8afa01580d67d'
          }
        ]
      end

      let(:currency) { Currency.find_by_id(:btc) }

      let!(:first_payment_address) do
        create(:btc_payment_address, address: '2N53Qy2KPYc6FBboYpuQmYroiSu8S6xthug')
      end

      let!(:second_payment_address) do
        create(:btc_payment_address, address: '2N9ufFR59zrxPETBaxEH51PcxAeJ2TyASVm')
      end

      before do
        # Mock requests and methods.
        client.class.any_instance.stubs(:latest_block_number).returns(latest_block)

        Deposits::Coin.where(currency: currency).delete_all

        block_data.each_with_index do |blk, index|
          # stub get_block_hash
          stub_request(:post, client.endpoint)
            .with(body: request_block_hash_body(blk['result']['height']))
            .to_return(body: {result: blk['result']['hash']}.to_json)

          # stub get_block
          stub_request(:post, client.endpoint)
            .with(body: request_block_body(blk['result']['hash']))
            .to_return(body: blk.to_json)
        end

        # Process blockchain data.
        BlockchainService[blockchain.key].process_blockchain(force: true)
      end

      subject { Deposits::Coin.where(currency: currency) }

      it 'creates two deposit' do
        expect(Deposits::Coin.where(currency: currency).count).to eq expected_deposits.count
      end

      it 'creates deposits with correct attributes' do
        expected_deposits.each do |expected_deposit|
          expect(subject.where(expected_deposit).count).to eq 1
        end
      end

      context 'we process same data one more time' do
        before do
          blockchain.update(height: start_block)
        end

        it 'doesn\'t change deposit' do
          expect(blockchain.height).to eq start_block
          expect{ BlockchainService[blockchain.key].process_blockchain(force: true)}.not_to change{subject}
        end
      end
    end

    context 'two BTC withdrawals were processed' do
      # File with real json rpc data for bunch of blocks.
      let(:block_file_name) { '1354649-1354651.json' }

      # Use rinkeby.etherscan.io to fetch transactions data.
      let(:expected_withdrawals) do
        [
          {
            sum:  0.30000000 + currency.withdraw_fee,
            rid:  '2N8ej8FhvQFT9Rw2Vfpiw5uv9CLuTh1BjFB',
            txid: '4a60db9608a3a7681808efbac83330c8191adadb7d26c67adb5acdf956eede8b'
          },
          {
            sum:  0.40000000 + currency.withdraw_fee,
            rid:  '2N5G6fEG3N4uZcXnQsE42YDM5nXq35m99Vx',
            txid: '8de7434cd62089b88d86f742fae32374a08f690cde2905e239c33e4e69ec5617'
          }
        ]
      end

      let(:member) { create(:member, :level_3, :barong) }
      let!(:btc_account) { member.get_account(:btc).tap { |a| a.update!(locked: 10, balance: 50) } }

      let!(:withdrawals) do
        expected_withdrawals.each_with_object([]) do |withdrawal_hash, withdrawals|
          withdrawal_hash.merge!\
            member: member,
            account: btc_account,
            aasm_state: :confirming,
            currency: currency
          withdrawals << create(:btc_withdraw, withdrawal_hash)
        end
      end

      let(:currency) { Currency.find_by_id(:btc) }

      before do
        # Mock requests and methods.
        client.class.any_instance.stubs(:latest_block_number).returns(latest_block)

        Deposits::Coin.where(currency: currency).delete_all

        block_data.each_with_index do |blk, index|
          # stub get_block_hash
          stub_request(:post, client.endpoint)
            .with(body: request_block_hash_body(blk['result']['height']))
            .to_return(body: {result: blk['result']['hash']}.to_json)

          # stub get_block
          stub_request(:post, client.endpoint)
            .with(body: request_block_body(blk['result']['hash']))
            .to_return(body: blk.to_json)
        end

        BlockchainService[blockchain.key].process_blockchain(force: true)
      end

      subject { Withdraws::Coin.where(currency: currency) }

      it 'doesn\'t create new withdrawals' do
        expect(subject.count).to eq expected_withdrawals.count
      end

      it 'changes withdraw confirmations amount' do
        subject.each do |withdrawal|
          expect(withdrawal.confirmations).to_not eq 0
        end
      end

      it 'changes withdraw state if it has enough confirmations' do
        subject.each do |withdrawal|
          if withdrawal.confirmations >= blockchain.min_confirmations
            expect(withdrawal.aasm_state).to eq 'succeed'
          end
        end
      end
    end
  end
end
