module Kifu
  module Tools

    class Helper
      
      def self.titleize(string)
         non_capitalized = %w{of etc and by the for on is at to but nor or a via}
         string.downcase.gsub(/\b[a-z]+/){ |w| non_capitalized.include?(w) ? w : w.capitalize  }.sub(/^[a-z]/){|l| l.upcase }.sub(/\b[a-z][^\s]*?$/){|l| l.capitalize }        
      end
      
      def self.marks_to_iso_date(item)
        string = item.to_s
        return '' if string.length < 5
        
        if string.length == 6
          yy = string[0,2]
          mm = string[2,2]
          dd = string[4,2]
        else
          yy = "0" + string[0,1]
          mm = string[1,2]
          dd = string[3,2]
        end
        yyyy = "20" + yy
        yyyy = "19" + yy if yy.to_i > 50
        
        Date.new(yyyy.to_i, mm.to_i, dd.to_i).to_s
      end
      
      def self.get_f_extension(year)
        if year >= 2000
          year = year - 2000
          if year < 10
            "F0#{year}"
          else
            "F#{year}"
          end
        else
          year = year - 1900
          "F#{year}"
        end
      end
      
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
      
      def self.opposite_relationship(kind)
        return 'spouse' if kind.downcase == 'spouse'
        return 'sibling' if kind.downcase == 'sibling'
        return 'parent' if kind.downcase == 'child'
        return 'child' if kind.downcase == 'parent'
        
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
        
        if kind.downcase == 'sibling'
          if relative_gender == 'F'
            return 'Sister'
          end
          if relative_gender == 'M'
            return 'Brother'
          end
          return 'Sibling'
        end
        
        if kind.downcase == 'child'
          if relative_gender == 'F'
            return 'Daughter'
          end
          if relative_gender == 'M'
            return 'Son'
          end
          return 'Child'
        end
        
        if kind.downcase == 'parent'
          if relative_gender == 'F'
            return 'Mother'
          end
          if relative_gender == 'M'
            return 'Father'
          end
          return 'Parent'
        end
        
        
        # Unable
        ''
      end
      
    end
  
  end
  
end
