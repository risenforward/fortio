module APIv2
  class Authenticator

    class <<self

      def urlsafe_string_40
        # 30 is picked so generated string length is 40
        SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
      end

      alias :generate_access_key :urlsafe_string_40
      alias :generate_secret_key :urlsafe_string_40

      def hmac_signature(secret_key, payload)
        OpenSSL::HMAC.hexdigest 'SHA256', secret_key, payload
      end

    end

    def initialize(request, params)
      @request = request
      @params  = params
    end

    def authentic?
      required_params_exist? && token && signature_match? && fresh?
    end

    def required_params_exist?
      @params[:access_key].present? && @params[:tonce].present? && @params[:signature].present?
    end

    def token
      @token ||= APIToken.where(access_key: @params[:access_key]).first
    end

    def signature_match?
      @params[:signature] == self.class.hmac_signature(token.secret_key, payload)
    end

    def fresh?
      timestamp = Time.at(@params[:tonce].to_i / 1000.0)
      timestamp > 5.minutes.ago
    end

    def payload
      @params
        .select {|k,v| !%w(route_info signature).include?(k) }.to_a
        .sort_by(&:first)
        .map {|pair| pair.join('=') }
        .join('&')
    end

  end
end
