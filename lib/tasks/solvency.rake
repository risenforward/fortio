require 'liability-proof'

namespace :solvency do

  task :btc_liability_proof => :environment do
    accounts = Account.with_currency(:btc).includes(:member)
    formatted_accounts = accounts.map do |account|
      { 'user'    => account.member.sn,
        'balance' => account.balance }
    end

    tree = LiabilityProof::Tree.new formatted_accounts, use_float: true

    puts "Generating root node .."
    proof = Proof.create!(root: tree.root_json)

    puts "Generating partial trees .."
    accounts.each do |acct|
      acct.update_attributes(partial_tree: tree.partial_json(acct.member.sn))
    end
    puts "#{accounts.size} partial trees generated."

    proof.ready!
    puts "Complete."
  end

end
