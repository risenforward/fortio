class FundSource < ActiveRecord::Base
  include Currencible

  attr_accessor :name

  paranoid

  belongs_to :member

  validates_presence_of :uid, :extra, :member

  def label
    if currency_obj.try :coin?
      [extra, uid].join('#')
    else
      [I18n.t("banks.#{extra}"), "****#{uid[-4..-1]}"].join('#')
    end
  end
end
