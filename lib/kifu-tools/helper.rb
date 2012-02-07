module Kifu
  module Tools

    class Helper
      
      def self.gender_from_prefix(prefix)
        value = prefix.downcase
        return 'F' if value =~ /^ms/
        return 'F' if value =~ /^mrs/
        return 'F' if value =~ /^miss/
        return 'M' if value =~ /^mr/
        return 'M' if value =~ /^rabbi/ # Assumed
        return 'M' if value =~ /^cantor/ # Assumed
        
        # Unable
        return ''
      end
      
      # KINDS_OF_PREFIX = ['', 'Mr.', 'Ms.', 'Mrs.', 'Dr.', 'Prof', 'Rev.', 'Adv.', 'Rabbi', 'Cantor']
      def self.trim_prefix(prefix)
        value = prefix.downcase
        return 'Ms.' if value =~ /^ms/
        return 'Mrs.' if value =~ /^mrs/
        return 'Ms.' if value =~ /^miss/
        return 'Mr.' if value =~ /^mr/
        return 'Dr.' if value =~ /^dr/
        return 'Prof' if value =~ /^prof/
        return 'Rev.' if value =~ /^rev/
        return 'Adv.' if value =~ /^adv/
        return 'Rabbi' if value =~ /^rabbi/
        return 'Cantor' if value =~ /^cantor/

        # Unable
        ''    
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
