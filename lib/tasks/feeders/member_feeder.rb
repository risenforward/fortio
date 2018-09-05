# encoding: UTF-8
# frozen_string_literal: true

class MemberFeeder < AbstractFeeder
  def feed(email)
    Member.transaction do
      member = Member.find_or_initialize_by(email: email)
      member.assign_attributes \
        level: 3
      member.save!
      member
    end
  end
end
