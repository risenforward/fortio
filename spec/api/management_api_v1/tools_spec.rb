describe ManagementAPIv1::Tools, type: :request do
  before do
    defaults_for_management_api_v1_security_configuration!
    management_api_v1_security_configuration.merge! \
      scopes: {
        tools: { permitted_signers: %i[alex jeff], mandatory_signers: %i[jeff] }
      }
  end

  describe '/timestamp' do
    let(:data) { {} }
    let(:signers) { %i[jeff] }

    def request
      post_json '/management_api/v1/timestamp',
                multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    it 'returns current time in seconds' do
      now = Time.now.to_i
      request
      expect(response).to be_success
      expect(JSON.parse(response.body).fetch('timestamp')).to be_between(now, now + 1)
    end
  end
end
