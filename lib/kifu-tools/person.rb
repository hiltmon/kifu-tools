#
# NOTE: The following fields needs to be set on save
# - sort_name
# - full_name
# - member (depends on tags)
# - status
#
# TODO: Set occupation and affiliation fields
# TODO: Add tags

module Kifu
  module Tools
    
    class Person < KifuModel
            
      def initialize(params = {})
        @model = {
          first_name: '',
          last_name: '',
          middle_name: '',
          prefix: '',
          suffix: '',
          gender: '',
          company_name: '',
          company_card: false,
          title: '',
          department: '',
          photo: '',
          legacy_id: '',
          account: false,
          account_since: '',
          account_close: '',
          occupation_id: '',
          affiliation_id: '',
          joined_at: '',
          salutation: '',
          alternate_name: '',
          nickname: '',
        }
        @model.merge!(params)
        
        # Assumptions
        # 1. No first name, must be a company
        if @model[:first_name] == ''
          @model[:company_name] = @model[:last_name]
          @model[:last_name] = ''
          @model[:company_card] = true 
        end
        
        # 2. No last name, must be a company
        if @model[:first_name] != '' && @model[:last_name] == ''
          @model[:company_name] = @model[:first_name]
          @model[:first_name] = ''
          @model[:company_card] = true 
        end
      end
      
      # def valid?
      #   errors.length == 0
      # end
      
      def errors
        array = []
        if @model[:company_card]
          array << "Must have a Company Name" if @model[:company_name] == ''
        else
          array << "Must have a First Name" if @model[:first_name] == ''
          array << "Must have a Last Name" if @model[:last_name] == ''
          array << "Must have a Gender" if @model[:gender] == ''
        end
        
        array
      end
      
      # def [](key)
      #   @model[key]
      # end
      # 
      # def []=(key, value)
      #   @model[key] = value
      # end
      # 
      # def to_csv
      #   '"' + @model.values.join('","') + '"'
      #   # "#{first_name},#{last_name},#{middle_name},#{prefix},#{suffix},#{gender},#{company_name},#{company_card},#{title},#{department},#{photo},#{legacy_id},#{account},#{account_since},#{account_close},#{member},#{occupation_id},#{affiliation_id},#{joined_at},#{salutation},#{alternate_name},#{nickname}"
      # end
      # 
      # def header
      #   @model.keys.join(',')
      #   # "first_name,last_name,middle_name,prefix,suffix,gender,company_name,company_card,title,department,photo,legacy_id,account,account_since,account_close,member,occupation_id,affiliation_id,joined_at,salutation,alternate_name,nickname"
      # end
      
    end
    
  end
end
