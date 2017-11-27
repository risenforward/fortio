module CoinRPC
  class XRP < BaseRPC
    R_B58_DICT = 'rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz'

    def currency
      Currency.find_by_code('xrp')
    end

    def handle(name, *args)
      post_body = { method: name, params: args }.to_json
      resp = JSON.parse(http_post_request(post_body))
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']
      result.symbolize_keys! if result.is_a? Hash
      result
    end

    def http_post_request(post_body)
      http    = Net::HTTP.new(@uri.host, @uri.port)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.basic_auth @uri.user, @uri.password
      request.content_type = 'application/json'
      request.body = post_body
      http.request(request).body
    rescue Errno::ECONNREFUSED
      raise ConnectionRefusedError
    end

    def getnewaddress(args = nil)
      resp = JSON.parse(RestClient.get("#{@rest_uri}/v1/wallet/new").body)
      raise JSONRPCError, resp['error'] if resp['error']
      resp['wallet']
    end

    def listtransactions(account, number = 100)
      post_body = {
        method: 'account_tx',
        params: [{
          account: account,
          ledger_index_max: -1,
          ledger_index_min: -1,
          limit: number
        }]
      }.to_json

      resp = JSON.parse(http_post_request(post_body))
      raise JSONRPCError, resp['error'] if resp['error']
      resp['result']['transactions'].map { |t| t['tx'] }
    end

    def gettransaction(txid)
      post_body = {
        method: 'tx',
        params: [
          transaction: txid,
          binary: false
        ]
      }.to_json

      resp = JSON.parse(http_post_request(post_body))
      raise JSONRPCError, resp['error'] if resp['error']

      {
        amount: resp['result']['Amount'].to_d / 1_000_000,
        confirmations: resp['result']['meta']['AffectedNodes'].size,
        timereceived: resp['result']['date'] + 946684800,
        txid: txid,
        details: [{
           account:  'payment',
           address:  resp['result']['Destination'],
           amount:   resp['result']['Amount'].to_d / 1_000_000,
           category: 'receive'
        }]
      }
    end

    def validateaddress(address = nil)
      post_body = {
        method: 'ledger_entry',
        params: [
          {
            account_root: address,
            ledger_index: 'validated',
            type: 'account_root'
          }
        ]
      }.to_json

      resp = JSON.parse(http_post_request(post_body))
      raise JSONRPCError, resp['error'] if resp['error']

      {
        isvalid: resp['result']['status'] == 'success',
        ismine: false,
        address: address
      }
    end

    def settxfee(fee)
      @tx_fee = fee * 1_000_000
    end

    def sendtoaddress(address, amount, fee)
      fs = FundSource.find_by(uid: address)
      issuer = fs.member.payment_addresses.find_by(currency: fs.currency_value)

      resp = JSON.parse(
        RestClient.get(
          "#{@rest_uri}/v1/accounts/#{issuer.address}/payments/paths/#{address}/#{amount}+XRP"
        ).body
      )

      uuid = JSON.parse(
        RestClient.get("#{@rest_uri}/v1/uuid").body
      )['uuid']

      resp = JSON.parse(
        RestClient.post(
          "#{@rest_uri}/v1/accounts/#{issuer.address}/payments",
          {
            secret: issuer.secret,
            payment: resp['payments'].last,
            client_resource_id: uuid
          }.to_json,
          content_type: :json,
          accept: :json
        ).body
      )

      Rails.logger.info("\n#{resp}")
      Rails.logger.info 'OK'

      Rails.logger.info(RestClient.get(resp['status_url']).body)
    end

    def getbalance(account = nil)
      post_body = {
        method: 'account_info',
        params: [
          account: account || Currency.find_by_code('xrp').assets['accounts'].sample['address'],
          strict: true,
          ledger_index: 'validated'
        ]
      }.to_json

      resp = JSON.parse(http_post_request(post_body))
      raise JSONRPCError, resp['error'] if resp['error']
      result = resp['result']['account_data']['Balance'].to_f / 1_000_000
      result
    end

    def safe_getbalance
      getbalance || 'N/A'
    end
  end
end
