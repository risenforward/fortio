class PartialTree < ActiveRecord::Base

  belongs_to :account
  belongs_to :proof

  serialize :json
  validates_presence_of :proof_id, :account_id, :json

end
