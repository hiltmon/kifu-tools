require 'dbf'
require 'json'

module Kifu
  module Tools

    class MarksImport
      
      def initialize(config, folder)
        raise "[#{config}] is not found" unless File.exists?(config)
        raise "[#{folder}] is not a directory path" unless File.directory?(folder)
        raise "[#{folder}] does not contain MARKS files" unless File.exists?("#{folder}/ESWSLNK1.DBF")
        @folder = Dir.new(folder)
        @config = JSON.parse(IO.read(config))
        
        @tags = {}
        @occupations = {}
        @people = {}
        @relationships = []
        @person_milestones = []
        @person_tags = []
        @addresses = []
        @phones = []
        @emails = []
      end
      
      def perform
        display_start
        
        generate_tag_file
        generate_occupation_file
        generate_people_file
        generate_email_file
        add_memorials_to_people
        add_children_to_people
        add_business_to_people
        add_more_tags_to_people
        
        display_end
      end
      
      private
      
      # -------------------------------------------------------------------------
      
      def generate_tag_file
        puts "  Loading " + Color.yellow("Tags") + "..."
        
        unless @config["tags"].nil?
          @config["tags"].each_pair do |key, value|
            @tags[key] = Tag.new(
              legacy_id: key,
              tag: value[:name],
              implies: value[:implies]
            )
          end
        end
        
        table = DBF::Table.new("#{@folder.path}/ESGRPCD.DBF")
        table.each do |record|
          next if record.nil?
          
          @tags[record.group] = Tag.new(
            legacy_id: record.group,
            tag: record.groupnme,
            implies: false
          )
        end
        
      end

      def generate_occupation_file
        puts "  Loading " + Color.yellow("Occupations") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESOCCUPC.DBF")
        table.each do |record|
          next if record.nil?
          
          @occupations[record.occupcd] = Occupation.new(name: record.occupate)
        end
      end
      
      # -------------------------------------------------------------------------
    
      def generate_people_file
        puts "  Loading " + Color.yellow("People") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESMNA1.DBF")
        table.each do |record|
          next if record.nil?
          
          person = generate_person_row(record)
          unless person.nil? || record.sfstname == ''
            spouse = generate_spouse_row(record, person)
          end
        end        
      end
      
      def generate_person_row(record)
        person = Person.new(
          last_name: record.lastname,
          first_name: record.frstname,
          legacy_id: record.acctnum,
          gender: MarksHelper::gender(record.title1, record.codes[2]), # Code 2 is person 1 gender
          salutation: record.lablname,
          prefix: Helper::trim_prefix(record.title1),
          account_since: record.membdate,
          account_close: record.quitdate,
        )
        
        if person.valid?
          @people[person[:legacy_id]] = person
            
          # If the person is valid, add milestones
          unless record.birth1 == ''
            @person_milestones << PersonMilestone.new(
              person_legacy_id: person[:legacy_id],
              milestone: 'Birth',
              on: record.birth1
            )
          end
          
          # Add their address
          unless record.haddr1 == '' && record.hcity == '' && record.hstate == '' && record.hzip == ''
            address = Address.new(
              person_legacy_id: person[:legacy_id],
              kind: 'home',
              pref: true,
              street: record.haddr1,
              extended: record.haddr2,
              city: record.hcity,
              state: record.hstate,
              post_code: record.hzip
            )
            if address.valid?
              @addresses << address
            else
              puts Color.cyan("  WARN ") + "Address" + Color.cyan(": #{address.errors.join(', ')} : #{person.description}")
            end
          end
          
          # Add their phones
          generate_phone(record.hphone1, person, 'home', true)
          generate_phone(record.hphone2, person, 'home', false)
          
          # Tag em
          unless record.codes[0].nil? || record.codes[0] == '' || record.codes[0] == ' '
            unless @tags[record.codes[0]].nil?
              person_tag = PersonTag.new(
                person_legacy_id: person[:legacy_id],
                tag_legacy_id: record.codes[0]
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": #{person_tag.errors.join(', ')} : #{person.description} (Tag is #{record.codes[0]})")
              end
            else
              puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": Invalid Tag Code : #{person.description} (Tag is #{record.codes[0]})")              
            end
          end
          
        else
          puts Color.red("  FAIL ") + "Person" + Color.red(": #{person.errors.join(', ')} : #{person.description}")
          return nil
        end
        
        person
      end
      
      def generate_spouse_row(record, person)
        # Add the spouse...
        spouse = Person.new(
          last_name: record.slstname == '' ? record.lastname : record.slstname,
          first_name: record.sfstname,
          legacy_id: record.acctnum + "-s",
          gender: MarksHelper::gender(record.title2, record.codes[3]), # Code 3 is person 1 gender 
          prefix: Helper::trim_prefix(record.title2)
        )
            
        if spouse.valid?
          @people[spouse[:legacy_id]] = spouse

          # And make the relationships
          generate_relationship('Spouse', person, spouse)
              
          # If the person is valid, add milestones
          unless record.birth2 == ''
            @person_milestones << PersonMilestone.new(
              person_legacy_id: spouse[:legacy_id],
              milestone: 'Birth',
              on: record.birth2
            )
          end
          
          unless record.anniv == ''
            @person_milestones << PersonMilestone.new(
              person_legacy_id: person[:legacy_id],
              milestone: 'Marriage',
              on: record.anniv
            )            
            @person_milestones << PersonMilestone.new(
              person_legacy_id: spouse[:legacy_id],
              milestone: 'Marriage',
              on: record.anniv
            )            
          end
        else
          puts Color.red("  FAIL ") + "Spouse" + Color.red(": #{spouse.errors.join(', ')} : #{spouse.description}")
          return nil
        end      
        
        spouse
      end
      
      def generate_phone(field, person, kind, pref)
        unless field == ''
          if field =~ /\d\d\d.\d\d\d/
            phone = Phone.new(
              person_legacy_id: person[:legacy_id],
              kind: kind,
              pref: pref,
              phone_number: field.match(/[0-9\-]*/).to_s.gsub(/--/, '-')
            )
            if phone.valid?
              @phones << phone
            else
              puts Color.cyan("  WARN ") + "Phone" + Color.cyan(": #{phone.errors.join(', ')} : #{person.description}")
            end
          end            
        end
        
      end
      
      # Does not generate any errors
      def generate_relationship(kind, person, relative)
        r1 = Relationship.new(
          person_legacy_id: person[:legacy_id],
          spouse_legacy_id: relative[:legacy_id],
          relationship: Helper::relationship(kind, person[:gender], relative[:gender])
        )
        @relationships << r1

        opp_kind = Helper::opposite_relationship(kind)
        r2 = Relationship.new(
          person_legacy_id: relative[:legacy_id],
          spouse_legacy_id: person[:legacy_id],
          relationship: Helper::relationship(opp_kind, relative[:gender], person[:gender])
        )
        @relationships << r2
      end
      
      # -------------------------------------------------------------------------
      
      def generate_email_file
        puts "  Loading " + Color.yellow("Emails") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESMNAMIS.DBF")
        table.each do |record|
          next if record.nil?

          # Find the person
          person = @people[record.acctnum]
          unless person.nil? && record.cmistext.length > 0 # && record.cmiscode == 'EMAIL'
            @emails << Email.new(
              person_legacy_id: person[:legacy_id],
              kind: 'home',
              pref: false,
              email_address: record.cmistext
            )
          end
        end
      end
      
      # -------------------------------------------------------------------------
      
      # Logic is
      # Need to load all them into memory
      # Then sort by lastname, firstname
      # Then walk from top to bottom
      # If the account is found then
      # If the 'next' person is the same name and has the same death date, add only the relationship
      # Else add the person and the relationship
      def add_memorials_to_people
        puts "  Loading " + Color.yellow("Memorials") + "..."
        
        # 1. Load them that we can
        memorial_people = build_all_valid_memorials
        
        last_memorial = TempMemorial.new() # Blank one
        new_legacy_number = 0
        memorial_people.each do |memorial_person|
          person = @people[memorial_person[:person_legacy_id]]
          next if person.nil? # Should never happen!
          
          relative = nil
          if match_memorial(memorial_person, last_memorial)
            memorial_person[:new_person_legacy_id] = last_memorial[:new_person_legacy_id]
            relative = @people[memorial_person[:new_person_legacy_id]]
          else
            new_legacy_number += 1
            memorial_person[:new_person_legacy_id] = "MEM#{"%05d" % new_legacy_number}"
            
            # Make the person
            relative = Person.new(
              last_name: memorial_person[:last_name],
              first_name: memorial_person[:last_name],
              legacy_id: memorial_person[:new_person_legacy_id],
              gender: memorial_person[:gender]           
            )
            if relative.valid?
              @people[relative[:legacy_id]] = relative
              
              @person_milestones << PersonMilestone.new(
                person_legacy_id: relative[:legacy_id],
                milestone: 'Death',
                on: memorial_person[:death_date]
              )
            else
              puts Color.cyan("  WARN ") + "Person" + Color.cyan(": #{relative.errors.join(', ')} : #{relative.description}")
              relative = nil
            end
          end
          
          puts "OOPS" if relative.nil?
          next if relative.nil?
          
          # Build the relationship
          if relative[:relationship] == "B" || relative[:relationship] == "HB" || relative[:relationship] == "HS" || relative[:relationship] == "SS" || relative[:relationship] == "SB" || relative[:relationship] == "SI"
            generate_relationship("Sibling", person, relative)
          end
          
          if relative[:relationship] == "D" || relative[:relationship] == "S" || relative[:relationship] == "SD" || relative[:relationship] == "SN"
            generate_relationship("Child", person, relative)
            try_code = person[:legacy_id] + "-s"
            spouse = @people[try_code]
            unless spouse.nil?
              generate_relationship("Child", spouse, relative)
            end
          end
          
          if relative[:relationship] == "F" || relative[:relationship] == "M" || relative[:relationship] == "SF" || relative[:relationship] == "SM"
            generate_relationship("Parent", person, relative)
          end
          
          if relative[:relationship] == "H" || relative[:relationship] == "W"
            generate_relationship("Spouse", person, relative)
          end
          
          if relative[:relationship] == "FL" || relative[:relationship] == "ML"
            try_code = person[:legacy_id] + "-s"
            spouse = @people[try_code]
            unless spouse.nil?
              generate_relationship("Parent", spouse, relative)
            end
          end
          
          last_memorial = memorial_person
        end 
        
      end
      
      # Get em all and sort em
      def build_all_valid_memorials
        memorial_people = []
        supported_relationships = [
          "B", # Brother 
          "SS", # Sister
          "HB", # Half Brother (Brother)
          "HS", # Half Sister (Sister)
          "SB", # Step Brother (Brother)
          "SI", # Step Sister (Sister)
          
          "D", # Daughter
          "S", # Son
          "SD", # Step Daughter (Daughter)
          "SN", # Step Son (Son)
          
          "F", # Father
          "M", # Mother
          "SF", # Step Father (Father)
          "SM", # Step Mother (Mother)

          "H", # Husband
          "W", # Wife

          "FL", # Father in Law
          "ML", # Mother in Law,          
        ]
        count_found = 0
        count_created = 0
        Dir.glob("#{@folder.path}ESYAHR*.DBF").each do |file_path|
          table = DBF::Table.new(file_path)
          table.each do |record|
            next if record.nil?
            count_found += 1
            
            next if record.eyeardcs == 0 || record.eyeardcs == ''
            next if supported_relationships.index(record.relate).nil?
            
            # Only add for real people (Makes no difference)
            # person = @people[record.acctnum]
            # next if person.nil?
            
            # Maka an ISO date
            day  = record.edateyhr.to_s[-2,2]
            month = record.edateyhr.to_s.sub(day, '')
            month = "0#{month}" if month.length == 1
            iso_date = "#{record.eyeardcs}-#{month}-#{day}"
            
            memorial = TempMemorial.new(
              person_legacy_id: record.acctnum,
              gender: record.sex,
              first_name: record.yfstname,
              last_name: record.ylstname,
              death_date: iso_date,
              relationship: record.relate
            )
            
            # No errors or warnings
            if memorial.valid?
              memorial_people << memorial
              count_created += 1
            else
              puts Color.cyan("  WARN ") + "Memorial" + Color.cyan(": #{memorial.errors.join(', ')} : #{memorial[:lst_name]}, #{memorial[:first_name]}")
            end
          end
        end
        
        memorial_people.sort {|a, b| "#{a[:last_name]},#{a[:firstname]}" <=> "#{b[:last_name]},#{b[:firstname]}"}
      end
      
      def match_memorial(m1, m2)
        m1[:last_name] == m2[:last_name] && m1[:first_name] == m2[:first_name] && m1[:death_date] == m2[:death_date]
      end
            
      # -------------------------------------------------------------------------
      
      def add_children_to_people
        puts "  Loading " + Color.yellow("Children") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESCHLD.DBF")
        table.each do |record|
          next if record.nil?

          # Find the person
          person = @people[record.acctnum]
          next if person.nil?

          # Make the child
          child = Person.new(
            last_name: record.frstname,
            first_name: record.lastname,
            legacy_id: record.acctnum + "-" + record.childnum,
            gender: record.sex,
            prefix: Helper::trim_prefix(record.title),
          )
          if child.valid?
            @people[child[:legacy_id]] = child
            
            # Children may have spouses in MARKS
            if record.sfstname != ''
              spouse = Person.new(
                last_name: record.slstname == '' ? record.lastname : record.slstname,
                first_name: record.sfstname,
                legacy_id: record.acctnum + "-" + record.childnum + "-s",
                gender: record.sex == "F" ? "M" : "F"
              )
            
              if spouse.valid?
                @people[spouse[:legacy_id]] = spouse

                # And make the relationships
                generate_relationship('Spouse', child, spouse)
              end
            end
            
            # Birthdates
            unless record.bday == ''
              @person_milestones << PersonMilestone.new(
                person_legacy_id: child[:legacy_id],
                milestone: 'Birth',
                on: record.bday
              )
            end
            
            unless record.bmdate == ''
              @person_milestones << PersonMilestone.new(
                person_legacy_id: child[:legacy_id],
                milestone: 'Bar/Batmitzvah',
                on: record.bmdate
              )
            end
            
            # Add their address
            if record.haddr1 != '' && record.hcity != '' && record.hstate != '' && record.hzip != ''
              address = Address.new(
                person_legacy_id: child[:legacy_id],
                kind: 'home',
                pref: true,
                street: record.haddr1,
                extended: record.haddr2,
                city: record.hcity,
                state: record.hstate,
                post_code: record.hzip
              )
              if address.valid?
                @addresses << address
              end
            end
          
            # Add their phones
            generate_phone(record.phone1, child, 'home', true)
            
            # Add the relationships
            generate_relationship('Child', person, child)
            
          else
            puts Color.red("  FAIL ") + "Child" + Color.red(": #{child.errors.join(', ')} : #{child.description}")
          end
        end
      end
      
      # -------------------------------------------------------------------------
      
      def add_business_to_people
        puts "  Loading " + Color.yellow("Business") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESBNA1.DBF")
        table.each do |record|
          next if record.nil?
          
          # Find the person
          legacy_key = record.acctnum
          legacy_key = record.acctnum + "-s" if record.reccd == "2"
          person = @people[legacy_key]
          
          # Create a company card? NO
          next if person.nil?
          
          person[:company_name] = record.firmname
          person[:occupation_id] = @occupations[record.occupcd]
          
          # Add their address
          unless record.baddr1 == '' && record.bcity == '' && record.bstate == '' && record.bzip == ''
            address = Address.new(
              person_legacy_id: person[:legacy_id],
              kind: 'work',
              street: record.baddr1,
              extended: record.baddr2,
              city: record.bcity,
              state: record.bstate,
              post_code: record.bzip
            )
            if address.valid?
              @addresses << address
            else
              puts Color.cyan("  WARN ") + "BusAddr" + Color.cyan(": #{address.errors.join(', ')} : #{person.description}")
            end
          end
          
          generate_phone(record.bphone1, person, 'work', false)
          generate_phone(record.bphone2, person, 'work', false)
        end
      end
      
      # -------------------------------------------------------------------------
      
      def add_more_tags_to_people
        puts "  Loading " + Color.yellow("Groups") + "..."
        
        table = DBF::Table.new("#{@folder.path}/ESGROUP.DBF")
        table.each do |record|
          next if record.nil?
        
          person = @people[record.acctnum]
          next if person.nil?
          
          # Person or spouse??
          if person[:first_name] != record.frstname
            # Try the spouse
            spouse = @people[record.acctnum + "-s"]
            person = spouse unless spouse.nil?
          end
          
          unless record.group == ''
            unless @tags[record.group].nil?
              person_tag = PersonTag.new(
                person_legacy_id: person[:legacy_id],
                tag_legacy_id: record.group
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": #{person_tag.errors.join(', ')} : #{person.description} (Group is #{record.group})")
              end
            else
              puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": Invalid Tag Code : #{person.description} (Group is #{record.group})")
            end
          end

          unless record.subgroup == ''
            unless @tags[record.subgroup].nil?
              person_tag = PersonTag.new(
                person_legacy_id: person[:legacy_id],
                tag_legacy_id: record.subgroup
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": #{person_tag.errors.join(', ')} : #{person.description} (Group is #{record.subgroup})")
              end
            else
              puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": Invalid Tag Code : #{person.description} (Group is #{record.subgroup})")
            end
          end
          
        end
      end
      
      # -------------------------------------------------------------------------
      
      def display_start
        puts Color.yellow("Marks Import ") + Color.green("Starting...")
      end
      
      def display_end
        puts Color.yellow("Marks Import Statistics")
        puts "           Tags: " + Color.green("#{@tags.keys.length}")
        puts "    Occupations: " + Color.green("#{@occupations.keys.length}")
        puts "         People: " + Color.green("#{@people.keys.length}")
        puts "  Relationships: " + Color.green("#{@relationships.length}")
        puts "     Milestones: " + Color.green("#{@person_milestones.length}")
        puts "    Person Tags: " + Color.green("#{@person_tags.length}")
        puts "      Addresses: " + Color.green("#{@addresses.length}")
        puts "         Phones: " + Color.green("#{@phones.length}")
        puts "         Emails: " + Color.green("#{@emails.length}")
        puts Color.yellow("Marks Import ") + Color.green("Done...")
      end
      
    end
    
  end
end