module Kifu
  module Tools

    class Helper
      
      # Prefix must be lowercase
      def self.gender_from_prefix(prefix)
        return 'F' if prefix =~ /^ms/
        return 'F' if prefix =~ /^mrs/
        return 'F' if prefix =~ /^miss/
        return 'M' if prefix =~ /^mr/
        return 'M' if prefix =~ /^rabbi/ # Assumed
        return 'M' if prefix =~ /^cantor/ # Assumed
        
        # Unable
        return ''
      end
      
      def self.relationship(kind, person_gender, relative_gender)
        if kind.downcase == 'spouse'
          if person_gender == 'M' && relative_gender == 'F'
            return 'Wife'
          end
          if person_gender == 'F' && relative_gender == 'M'
            return 'Husband'
          end
          return 'Spouse'
        end
        
        # Unable
        ''
      end
      
    end
  
  end
  
end
