
module Kifu
  module Tools
    
    class Deposit < KifuModel
            
      def initialize(params = {})
        @model = {
          legacy_id: '',
          deposit_date: '',
          bank_account_id: '',
          status: 'Open',
          posted_amount: '',
          posted: false
        }
        @model.merge!(params)
      end
      
      def errors
        array = []

        array << "Must have a legacy id" if @model[:legacy_id] == ''
        array << "Must have a deposit date" if @model[:deposit_date] == ''
        array << "Must have a bank account" if @model[:bank_account_id] == ''
        
        array
      end
      
    end
    
  end
end
