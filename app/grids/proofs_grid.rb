# encoding: UTF-8
# frozen_string_literal: true

class ProofsGrid
  include Datagrid

  scope { Proof.order(id: :desc) }

  filter(:id, :integer)
  filter(:created_at, :date, range: true)

  column(:id)
  column(:currency) { |p| p.currency_id.upcase }
  column(:balance)
  column(:sum)
  column(:created_at) { |p| p.created_at.to_date }
  column(:actions, html: true, header: '') { |proof| link_to I18n.t('actions.edit'), edit_admin_proof_path(proof) }
end
