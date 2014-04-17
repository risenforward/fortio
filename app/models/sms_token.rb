class SmsToken < Token

  VERIFICATION_CODE_LENGTH = 6

  attr_accessor :phone_number
  attr_accessor :verify_code

  validates_uniqueness_of :token, scope: :member_id
  validates :phone_number, phone: { possible: true, allow_blank: true, types: [:mobile] }

  class << self
    def for_member(member)
      return member.create_sms_token if member.sms_token.blank?

      if member.sms_token && !member.sms_token.expired?
        member.sms_token
      else
        member.sms_token.destroy
        member.create_sms_token
      end
    end
  end

  def generate_token
    begin
      self.is_used = false
      self.token = VERIFICATION_CODE_LENGTH.times.map{ Random.rand(9) + 1 }.join
      self.expire_at = DateTime.now.since(60 * 30)
    end while SmsToken.where(member_id: member_id, token: token).any?
  end

  def expired?
    expire_at <= Time.now
  end

end
