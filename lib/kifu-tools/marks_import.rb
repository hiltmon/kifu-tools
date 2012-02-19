require 'dbf'
require 'json'

module Kifu
  module Tools

    class MarksImport
      
      def initialize(config, folder, dest)
        raise "[#{config}] is not found" unless File.exists?(config)
        raise "[#{folder}] is not a directory path" unless File.directory?(folder)
        raise "[#{folder}] does not contain MARKS files" unless File.exists?("#{folder}/ESWSLNK1.DBF")
        Dir.mkdir(dest) unless File.directory?(dest)
        @folder = Dir.new(folder)
        @dest = Dir.new(dest)
        @file = File.new("#{dest}/log.markdown", "w")
        @config = JSON.parse(IO.read(config))
        
        @import_start_year = @config["import"]["start_year"].to_i
        @import_start_date = Date.new(@import_start_year, @config["company"]["fiscal_year_month"], 1)  
        @marks = @config["marks"]
        
        @internal_batch_code = 0
        @internal_batch_count = 20 # Triggers a new batch code
        
        @chart_accounts = {}
        @tags = {}
        @occupations = {}
        @people = {}
        @relationships = []
        @person_milestones = []
        @person_tags = []
        @addresses = []
        @phones = []
        @emails = []
        
        @events = {}
        @attendings = {}
        @billings = {}
        
        @temp_batches = {}
        @deposits = {}
        @payments = {}
        @allocations = []
      end
      
      def perform
        display_start
        
        generate_chart_accounts_file
        generate_tag_file
        generate_occupation_file
        generate_people_file
        generate_email_file
        add_memorials_to_people
        add_children_to_people
        add_business_to_people
        add_more_tags_to_people
        
        # Events
        load_regular_events
        load_tribute_events

        # Billings        
        generate_attendings
        generate_billings # This is special :)
        
        load_temp_batches
        generate_deposit_payment_allocations_for_payments
        generate_deposit_payment_allocations_for_contributions
        adjust_billings
        generate_reallocations # No idea how to make work

        write_files
        
        display_end
      end
      
      private

      # -------------------------------------------------------------------------
      
      def display_heading(action, message)
        puts "#{message} : " + Color.green(action) + "..."
        @file.puts "\n# #{message} : " + action + "...\n"
      end
      
      def display_item(item, value)
        puts "  #{item} : " + Color.green(value)
        @file.puts "\n* #{item} : #{value}\n"
      end
      
      def display_action(action, message)
        puts action + " " + Color.yellow(message) + "..."
        @file.puts "\n## " + action + " #{message}...\n\n"
      end
      
      def display_fail(item, message)
        puts Color.red("  FAIL ") + item + " : " + Color.red(message)
        @file.puts "* *FAIL #{item} : #{message}*"
      end
      
      def display_warn(item, message)
        puts Color.cyan("  WARN ") + item + " : "+ Color.cyan(message)
        @file.puts "* WARN #{item} : #{message}"
      end
      
      def display_count(hash)
        @file.puts "\n"
        @file.puts "Processed:\n\n"
        print "Processed: "
        hash.each_pair do |key, value|
          print "#{key}: " + Color.green(value) + ", "
          @file.puts "* #{key}: #{value}"
        end
        @file.puts "\n"
        puts
      end
      
      # -------------------------------------------------------------------------
            
      def generate_chart_accounts_file
        display_action "Loading", "Chart Accounts"
        
        table = DBF::Table.new("#{@folder.path}/ESRTRCDS.DBF")
        table.each do |record|
          next if record.nil?
          
          # Assuming income, bank and receivable is the order of codes
          @chart_accounts[record.glcode] = ChartAccount.new(
            code: record.glcode,
            name: record.glcode,
            kind: 'Income'
          )

          @chart_accounts[record.glcode2] = ChartAccount.new(
            code: record.glcode2,
            name: record.glcode2,
            kind: 'Bank'
          )

          @chart_accounts[record.glcode3] = ChartAccount.new(
            code: record.glcode3,
            name: record.glcode3,
            kind: 'Receivable'
          )
        end
        
      end
      
      # -------------------------------------------------------------------------
      
      def generate_tag_file
        display_action "Loading", "Tags"
        
        unless @config["tags"].nil?
          @config["tags"].each_pair do |key, value|
            @tags[key] = Tag.new(
              legacy_id: key,
              name: value["name"],
              implies: value["implies"]
            )
          end
        end
        
        table = DBF::Table.new("#{@folder.path}/ESGRPCD.DBF")
        table.each do |record|
          next if record.nil?
          
          @tags[record.group] = Tag.new(
            legacy_id: record.group,
            name: record.groupnme,
            implies: false
          )
        end
        
      end

      def generate_occupation_file
        display_action "Loading", "Occupations"
        
        table = DBF::Table.new("#{@folder.path}/ESOCCUPC.DBF")
        table.each do |record|
          next if record.nil?
          
          @occupations[record.occupcd] = Occupation.new(name: record.occupate, :legacy_id => record.occupcd)
        end
      end
      
      # -------------------------------------------------------------------------
    
      def generate_people_file
        display_action "Loading", "People"
        
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
          gender: MarksHelper::gender(record.title1, record.codes[@marks["person_gender_code"].to_i]),
          salutation: record.lablname,
          prefix: Helper::trim_prefix(record.title1),
          account_since: record.membdate,
          account_close: record.quitdate,
          account: true
        )
        
        if person.valid?
          @people[person[:legacy_id]] = person
            
          # If the person is valid, add milestones
          unless record.birth1.blank?
            @person_milestones << PersonMilestone.new(
              person_id: person[:legacy_id],
              milestone_id: 1,
              on: record.birth1
            )
          end
          
          # Add their address
          unless record.haddr1.blank? && record.hcity.blank? && record.hstate.blank? && record.hzip.blank?
            address = Address.new(
              person_id: person[:legacy_id],
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
              display_warn "Address", "#{address.errors.join(', ')} : #{person.description}"
            end
          end
          
          # Add their phones
          generate_phone(record.hphone1, person, 'home', true)
          generate_phone(record.hphone2, person, 'home', false)
          
          # Tag em
          unless record.codes[@marks["membership_tag_code"].to_i].blank? || record.codes[@marks["membership_tag_code"].to_i] == ' '
            unless @tags[record.codes[@marks["membership_tag_code"].to_i]].nil?
              person_tag = PersonTag.new(
                person_id: person[:legacy_id],
                tag_id: record.codes[@marks["membership_tag_code"]]
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                display_warn "PersonTag", "#{person_tag.errors.join(', ')} : #{person.description} (Tag is #{record.codes[@marks["membership_tag_code"]]})"
              end
            else
              display_warn "PersonTag", "Invalid Tag Code : #{person.description} (Tag is #{record.codes[@marks["membership_tag_code"]]})"
            end
          end
          
        else
          display_fail "Person", "#{person.errors.join(', ')} : #{person.description}"
          return nil
        end
        
        person
      end
      
      def generate_spouse_row(record, person)
        # Add the spouse...
        spouse = Person.new(
          last_name: record.slstname.blank? ? record.lastname : record.slstname,
          first_name: record.sfstname,
          legacy_id: record.acctnum + "-s",
          gender: MarksHelper::gender(record.title2, record.codes[@marks["spouse_gender_code"].to_i]),
          prefix: Helper::trim_prefix(record.title2)
        )
            
        if spouse.valid?
          @people[spouse[:legacy_id]] = spouse

          # And make the relationships
          generate_relationship('Spouse', person, spouse)
              
          # If the person is valid, add milestones
          unless record.birth2.blank?
            @person_milestones << PersonMilestone.new(
              person_id: spouse[:legacy_id],
              milestone_id: 1,
              on: record.birth2
            )
          end
          
          unless record.anniv.blank?
            @person_milestones << PersonMilestone.new(
              person_id: person[:legacy_id],
              milestone_id: 5,
              on: record.anniv
            )            
            @person_milestones << PersonMilestone.new(
              person_id: spouse[:legacy_id],
              milestone_id: 5,
              on: record.anniv
            )            
          end
        else
          display_fail "Spouse", "#{spouse.errors.join(', ')} : #{spouse.description}"
          return nil
        end      
        
        spouse
      end
      
      def generate_phone(field, person, kind, pref)
        unless field.blank?
          if field =~ /\d\d\d.\d\d\d/
            phone = Phone.new(
              person_id: person[:legacy_id],
              kind: kind,
              pref: pref,
              phone_number: field.match(/[0-9\-]*/).to_s.gsub(/--/, '-')
            )
            if phone.valid?
              @phones << phone
            else
              display_warn "Phone", "#{phone.errors.join(', ')} : #{person.description}"
            end
          end            
        end
        
      end
      
      # Does not generate any errors
      def generate_relationship(kind, person, relative)
        r1 = Relationship.new(
          person_id: person[:legacy_id],
          relative_id: relative[:legacy_id],
          relationship: Helper::relationship(kind, person[:gender], relative[:gender])
        )
        @relationships << r1

        opp_kind = Helper::opposite_relationship(kind)
        r2 = Relationship.new(
          person_id: relative[:legacy_id],
          relative_id: person[:legacy_id],
          relationship: Helper::relationship(opp_kind, relative[:gender], person[:gender])
        )
        @relationships << r2
      end
      
      # -------------------------------------------------------------------------
      
      def generate_email_file
        display_action "Loading", "Emails"
        
        table = DBF::Table.new("#{@folder.path}/ESMNAMIS.DBF")
        table.each do |record|
          next if record.nil?

          # Find the person
          person = @people[record.acctnum]
          unless person.nil? || record.cmistext.blank?
            @emails << Email.new(
              person_id: person[:legacy_id],
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
        display_action "Loading", "Memorials"
        
        # 1. Load them that we can
        memorial_people = build_all_valid_memorials
        
        last_memorial = TempMemorial.new() # Blank one
        new_legacy_number = 0
        memorial_people.each do |memorial_person|
          person = @people[memorial_person[:person_id]]
          display_warn("Memorial", "Person not found : #{memorial_person[:person_id]}") if person.nil?
          next if person.nil? # Should never happen!
          
          relative = nil
          if match_memorial(memorial_person, last_memorial)
            memorial_person[:new_person_id] = last_memorial[:new_person_id]
            relative = @people[memorial_person[:new_person_id]]
          else
            new_legacy_number += 1
            memorial_person[:new_person_id] = "MEM#{"%05d" % new_legacy_number}"
            
            # Make the person
            relative = Person.new(
              last_name: memorial_person[:last_name],
              first_name: memorial_person[:first_name],
              legacy_id: memorial_person[:new_person_id],
              gender: memorial_person[:gender]           
            )
            if relative.valid?
              @people[relative[:legacy_id]] = relative
              
              @person_milestones << PersonMilestone.new(
                person_id: relative[:legacy_id],
                milestone_id: 2,
                on: memorial_person[:death_date]
              )
            else
              display_warn "Person", "#{relative.errors.join(', ')} : #{relative.description}"
              relative = nil
            end
          end
          
          # puts "OOPS" if relative.nil?
          next if relative.nil?
          
          # Build the relationship
          if memorial_person[:relationship] == "B" || memorial_person[:relationship] == "HB" || memorial_person[:relationship] == "HS" || memorial_person[:relationship] == "SS" || memorial_person[:relationship] == "SB" || memorial_person[:relationship] == "SI"
            generate_relationship("Sibling", person, relative)
          end
          
          if memorial_person[:relationship] == "D" || memorial_person[:relationship] == "S" || memorial_person[:relationship] == "SD" || memorial_person[:relationship] == "SN"
            generate_relationship("Child", person, relative)
            try_code = person[:legacy_id] + "-s"
            spouse = @people[try_code]
            unless spouse.nil?
              generate_relationship("Child", spouse, relative)
            end
          end
          
          if memorial_person[:relationship] == "F" || memorial_person[:relationship] == "M" || memorial_person[:relationship] == "SF" || memorial_person[:relationship] == "SM"
            generate_relationship("Parent", person, relative)
          end
          
          if memorial_person[:relationship] == "H" || memorial_person[:relationship] == "W"
            generate_relationship("Spouse", person, relative)
          end
          
          if memorial_person[:relationship] == "FL" || memorial_person[:relationship] == "ML"
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
            
            next if record.eyeardcs == 0 || record.eyeardcs.blank?
            next if supported_relationships.index(record.relate).nil?
            
            # Is this for the person or their spouse (the in-law issue)
            person = @people[record.acctnum]
            display_warn("Memorial", "Person not found : #{record.acctnum}") if person.nil?
            next if person.nil?

            person_legacy_id = record.acctnum
            if record.frstname != person[:first_name]
              # try the spouse
              spouse = @people[record.acctnum + "-s"]
              unless spouse.nil?
                if record.frstname == spouse[:first_name]
                  person_legacy_id = record.acctnum + "-s"
                end
              end
            end
            
            # Make an ISO date
            day  = record.edateyhr.to_s[-2,2]
            month = record.edateyhr.to_s.sub(day, '')
            month = "0#{month}" if month.length == 1
            iso_date = "#{record.eyeardcs}-#{month}-#{day}"
            
            memorial = TempMemorial.new(
              person_id: person_legacy_id,
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
              display_warn "Memorial", "#{memorial.errors.join(', ')} : #{memorial[:lst_name]}, #{memorial[:first_name]}"
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
        display_action "Loading", "Children"
        
        table = DBF::Table.new("#{@folder.path}/ESCHLD.DBF")
        table.each do |record|
          next if record.nil?

          # Find the person
          person = @people[record.acctnum]
          next if person.nil?

          # Make the child
          child = Person.new(
            last_name: record.lastname,
            first_name: record.frstname,
            legacy_id: record.acctnum + "-" + record.childnum,
            gender: record.sex,
            prefix: Helper::trim_prefix(record.title),
          )
          if child.valid?
            @people[child[:legacy_id]] = child
            
            # Children may have spouses in MARKS
            if record.sfstname.present?
              spouse = Person.new(
                last_name: record.slstname.blank? ? record.lastname : record.slstname,
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
            unless record.bday.blank?
              @person_milestones << PersonMilestone.new(
                person_id: child[:legacy_id],
                milestone_id: 1,
                on: record.bday
              )
            end
            
            unless record.bmdate.blank?
              @person_milestones << PersonMilestone.new(
                person_id: child[:legacy_id],
                milestone_id: 7,
                on: record.bmdate
              )
            end
            
            # Add their address
            if record.haddr1.present? && record.hcity.present? && record.hstate.present? && record.hzip.present?
              address = Address.new(
                person_id: child[:legacy_id],
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
            display_fail "Child", "#{child.errors.join(', ')} : #{child.description}"
          end
        end
      end
      
      # -------------------------------------------------------------------------
      
      def add_business_to_people
        display_action "Loading", "Business"
        
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
          person[:occupation_id] = @occupations[record.occupcd].nil? ? '' : @occupations[record.occupcd][:name]
          
          # Add their address
          unless record.baddr1.blank? && record.bcity.blank? && record.bstate.blank? && record.bzip.blank?
            address = Address.new(
              person_id: person[:legacy_id],
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
              display_warn "BusAddr", "#{address.errors.join(', ')} : #{person.description}"
            end
          end
          
          generate_phone(record.bphone1, person, 'work', false)
          generate_phone(record.bphone2, person, 'work', false)
        end
      end
      
      # -------------------------------------------------------------------------
      
      def add_more_tags_to_people
        display_action "Loading", "Groups"
        
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
          
          unless record.group.blank?
            unless @tags[record.group].nil?
              person_tag = PersonTag.new(
                person_id: person[:legacy_id],
                tag_id: record.group
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                display_warn "PersonTag", "#{person_tag.errors.join(', ')} : #{person.description} (Group is #{record.group})"
              end
            else
              display_warn "PersonTag", "Invalid Tag Code : #{person.description} (Group is #{record.group})"
            end
          end

          unless record.subgroup.blank?
            unless @tags[record.subgroup].nil?
              person_tag = PersonTag.new(
                person_id: person[:legacy_id],
                tag_id: record.subgroup
              )
              if person_tag.valid?
                @person_tags << person_tag
              else
                display_warn "PersonTag", "#{person_tag.errors.join(', ')} : #{person.description} (Group is #{record.subgroup})"
              end
            else
              display_warn "PersonTag", "Invalid Tag Code : #{person.description} (Group is #{record.subgroup})"
            end
          end
          
        end
      end
      
      # -------------------------------------------------------------------------
      
      def load_regular_events
        display_action "Loading", "Regular Events"
        
        table = DBF::Table.new("#{@folder.path}/ESRTRCDS.DBF")
        table.each do |record|
          next if record.nil?

          legacy_id = record.trancode.strip
          legacy_id = "0#{legacy_id}" if legacy_id.length < 2
          
          year = @config["import"]["start_year"]
          display_end = @config["import"]["year_is_at_end_of_period"]
          display_year = (display_end.nil? ? year + 1 : (display_end ? year + 1 : year))
          year_start_date = Date.new(year, @config["company"]["fiscal_year_month"], 1)
          old_legacy_id = ''
          while year_start_date <= Date.today
            special_legacy_id = legacy_id + year.to_s[-2,2]
            event = Event.new(
              legacy_id: special_legacy_id,
              name: "#{display_year} - #{Helper::titleize(record.trandesc)}",
              detail: Helper::titleize(record.trandsc2),
              income_account_id: record.glcode,
              bank_account_id: record.glcode2,
              status: (year_start_date < Date.new(Date.today.year-1, Date.today.month, Date.today.day) ? 'Closed' : 'Open'),
              start_at: year_start_date.to_s,
              end_at: (Date.new(year+1, @config["company"]["fiscal_year_month"], 1) - 1).to_s,
              old_event_id: old_legacy_id
            )
            
            if event.valid?
              @events[event[:legacy_id]] = event
              
              old_legacy_id = special_legacy_id.dup
            else
              display_fail "Event", "#{event.errors.join(', ')} : #{event[:name]}"
            end
            
            year += 1
            display_year += 1
            year_start_date = Date.new(year, @config["company"]["fiscal_year_month"], 1)
          end
        end
      end
      
      def load_tribute_events
        # Optional
        return unless File.exists?("#{@folder.path}/ESRBTRIM.DBF")
        
        display_action "Loading", "Tribute Events"
        
        table = DBF::Table.new("#{@folder.path}/ESRBTRIM.DBF")
        table.each do |record|
          next if record.nil?

          legacy_id = record.ceventcd.strip
          legacy_id = "0#{legacy_id}" if legacy_id.length < 2
          
          year = @config["import"]["start_year"]
          display_end = @config["import"]["year_is_at_end_of_period"]
          display_year = (display_end.nil? ? year + 1 : (display_end ? year + 1 : year))
          year_start_date = Date.new(year, @config["company"]["fiscal_year_month"], 1)
          old_legacy_id = ''
          while year_start_date <= Date.today
            special_legacy_id = legacy_id + year.to_s[-2,2]
            event = Event.new(
              legacy_id: special_legacy_id,
              name: "#{display_year} - #{Helper::titleize(record.ceventdsc)}",
              income_account_id: @marks["tribute_income_account_code"],
              bank_account_id: @marks["tribute_bank_account_code"],
              status: (year_start_date < Date.new(Date.today.year-1, Date.today.month, Date.today.day) ? 'Closed' : 'Open'),
              start_at: year_start_date.to_s,
              end_at: (Date.new(year+1, @config["company"]["fiscal_year_month"], 1) - 1).to_s,
              old_event_id: old_legacy_id
            )
            
            if event.valid?
              if @events[event[:legacy_id]].present?
                if @events[event[:legacy_id]][:name] != event[:name]
                  # puts Color.cyan("  WARN ") + "Event", "Tribute event matches regular event, different name : #{event[:name]}")
                end
                
              else
                display_warn "Event", "Tribute not in events, added : #{event[:name]}"
                @events[event[:legacy_id]] = event
              end
              
              old_legacy_id = special_legacy_id.dup
            else
              display_fail "Event", "#{event.errors.join(', ')} : #{event[:name]}"
            end
            
            year += 1
            display_year += 1
            year_start_date = Date.new(year, @config["company"]["fiscal_year_month"], 1)
          end
        end
      end
      
      # -------------------------------------------------------------------------
      
      def generate_attendings

        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_attendings_from_file "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}"
          process_year += 1
        end
        
        generate_attendings_from_file "Current YTD", "#{@folder.path}/ESRBYTD.DBF"
      end
      
      def generate_attendings_from_file(which, file_path)
        display_action "Pass 1", "#{which} Attendings"
        table = DBF::Table.new(file_path)
        count_found = 0
        count_created = 0
        count_dups = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'B' # Assume BILLING
          
          count_found += 1
          
          result = add_attending(record, true)
          
          count_created += 1 if result == 1
          count_dups += 1 if result == 0
        end
        display_count({"Found" => count_found, "Created" => count_created, "Dups" => count_dups})
      end
      
      def add_attending(record, increment)
        person = @people[record.acctnum]
        event = @events[Helper::to_legacy_id(record.trnscdyr)]
          
        if person.present? && event.present?
          key = "#{person[:legacy_id]}/#{event[:legacy_id]}"
          if @attendings[key].nil?
            @attendings[key] = Attending.new(
              person_id: person[:legacy_id],
              event_id: event[:legacy_id]
            )
            
            # And set the event billing amount
            if event[:regular_attendance_fee].blank?
              event[:regular_attendance_fee] = record.trnsamnt
            else
              event[:regular_attendance_fee] = [event[:regular_attendance_fee], record.trnsamnt].max
            end            
          
            return 1
          else
            # If already attending and the fee is the same as the event fee, add one.
            if increment == true
              if event[:regular_attendance_fee].to_f == record.trnsamnt.to_f
                @attendings[key][:no_of] = @attendings[key][:no_of] + 1
              else
                display_warn "Attending", "Billing differs from event fee, not increasing attendings (#{event[:regular_attendance_fee]} <=> #{record.trnsamnt.to_f}): #{key}."
              end
            end
            return 0
          end
        end
        
        if person.nil?
          display_warn "Attending", "Unable to create attending for person: #{record.acctnum}."
        end
        if event.nil?
          # Only log errors for those after import period
          unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
            display_warn "Attending", "Unable to create attending for event: #{record.trnscdyr}."
          end
        end
        return -1 # Something went wrong, or not...
      end
      
      # -------------------------------------------------------------------------
      
      def generate_billings
        
        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_billings_from_file "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}"
          process_year += 1
        end
        
        generate_billings_from_file "Current YTD", "#{@folder.path}/ESRBYTD.DBF"
      end
      
      def generate_billings_from_file(which, file_path)
        display_action "Pass 2", "#{which} Billings"
        table = DBF::Table.new(file_path)
        count_found = 0
        count_created = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'B' # Assume BILLING
          
          count_found += 1
          
          if add_billing(record, 'Attendance') == 1
            # event = @events[Helper::to_legacy_id(record.trnscdyr)]
            # 
            # # And set the event billing amount
            # if event[:regular_attendance_fee].blank?
            #   event[:regular_attendance_fee] = record.trnsamnt
            # else
            #   event[:regular_attendance_fee] = [event[:regular_attendance_fee], record.trnsamnt].max
            # end
            
            count_created += 1
          end
        end
        display_count({"Found" => count_found, "Created" => count_created})
      end
      
      def add_billing(record, kind)
        person = @people[record.acctnum]
        legacy_id = record.trnscdyr.strip
        legacy_id = "0#{legacy_id}" if legacy_id.length < 4
        event = @events[legacy_id]
          
        if person.present? && event.present?
          key_part = "#{person[:legacy_id]}/#{event[:legacy_id]}"
          extend_part = kind[0]
          
          # Check attending
          attending = @attendings[key_part]
          display_warn("Billing", "No attending for #{key_part}.") if attending.nil?
          
          billing = Billing.new(
            legacy_id: "#{key_part}/#{extend_part}",
            person_id: person[:legacy_id],
            event_id: event[:legacy_id],
            bill_date: Helper::marks_to_iso_date(record.trnsdate),
            bill_for: kind,
            bill_amount: record.trnsamnt,
            payable_amount: record.trnsamnt
          )
            
          if billing.valid?
            # Ignore double billings as the attendance hack applies on import
            # Unless the amount differs
            if @billings[billing[:legacy_id]].present?
              old_billing = @billings[billing[:legacy_id]]
              
              if old_billing[:bill_amount] != billing[:bill_amount]
                # Its an adjustment?
                billing[:bill_amount] = billing[:bill_amount].to_f + old_billing[:bill_amount].to_f
                billing[:payable_amount] = billing[:payable_amount].to_f + old_billing[:payable_amount].to_f
                display_warn("Billing", "Looks like billing is being adjusted, not duplicated #{key_part}.") if attending.nil?
              else
                billing[:payable_amount] = billing[:payable_amount].to_f + old_billing[:payable_amount].to_f
              end
            end
            
            # puts Color.red("Double Billing? #{billing[:legacy_id]}") if @billings[billing[:legacy_id]].present?
            @billings[billing[:legacy_id]] = billing
            return 1
          else
            display_warn "Billing", "#{billing.errors.join(', ')} : #{billing[:legacy_id]}"
            return 0
          end
        end
        
        if person.nil?
          display_warn "Billing", "Unable to create billing for person: #{record.acctnum}."
        end
        if event.nil?
          # Only log errors for those after import period
          unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
            display_warn "Billing", "Unable to create billing for event: #{record.trnscdyr}."
          end
        end
        return -1 # Something went wrong, or not...
      end
      
      # -------------------------------------------------------------------------
      
      def load_temp_batches
        display_action "Loading", "Batches"
        count_found = 0
        count_created = 0
        
        table = DBF::Table.new("#{@folder.path}/ESRBTCHN.DBF")
        table.each do |record|
          next if record.nil?
          
          count_found += 1
          
          batch = TempBatch.new(
            legacy_id: record.batchnum.sub(/ESRB/, ''),
            batch_date: Helper::marks_to_iso_date(record.batdate),
            batch_count: record.batntrns.to_i
          )
          
          if batch.valid?
            @temp_batches[batch[:legacy_id]] = batch
            count_created += 1
          end
        end
        display_count({"Found" => count_found, "Created" => count_created})
      end
      
      # -------------------------------------------------------------------------
      
      def generate_deposit_payment_allocations_for_payments
        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_for_payments "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}", process_year
          process_year += 1
        end
        
        generate_for_payments "Current YTD", "#{@folder.path}/ESRBYTD.DBF", Date.today.year
      end
      
      def generate_for_payments(which, file_path, year)
        display_action "Pass 3", "#{which} Deposits, Payments and Allocations (P)"
        
        table = DBF::Table.new(file_path)
        count_found = 0
        count_created = 0
        count_adjusted = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'P'
          next if record.bnum.blank? # Ignore carry forwards
          
          count_found += 1
          
          deposit = find_or_create_deposit(record.bnum, record.trnsdate)
          if deposit.nil?
            display_fail "Deposit", "Batch not found : #{record.bnum}"
            next
          end
          
          # Make a payment...
          person = @people[record.acctnum]
          if person.nil?
            display_fail "Deposit", "Person not found, unable to save payment : #{record.acctnum}"
            next
          end
          
          # If the amount is positive, create a payment
          if record.trnsamnt.to_f >= 0
            payment = Payment.new(
              legacy_id: "#{person[:legacy_id]}/#{record.trnscdyr}/#{@payments.keys.count}/PP",
              deposit_id: deposit[:legacy_id],
              person_id: person[:legacy_id],
              kind: 'Check',
              # reference_code: '',
              payment_amount: record.trnsamnt,
              allocated_amount: 0.0,
              note: record.comment.gsub(/"/, "'"),
              # third_party_id: '',
              # honor: '',
              # honoree: '',
              # notify_id: '',
              # decline_date: '',
              # decline_posted: false,
              # refund_amount: 0
            )
            @payments[payment[:legacy_id]] = payment
          
            event = @events[Helper::to_legacy_id(record.trnscdyr)]
          
            if event.nil?
              # Only log errors for those after import period
              unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
                display_warn "Allocation", "Event not found, unable to allocate : #{record.trnscdyr}"
              end
              next
            end
          
            # Allocate to the attendance billing
            @allocations << Allocation.new(
              payment_id: payment[:legacy_id],
              billing_id: "#{person[:legacy_id]}/#{event[:legacy_id]}/A",
              allocation_amount: record.trnsamnt
            )
            count_created += 1
          else
            # The payment amount is negative, reduce the last payment by person, event to this amount
            # Test to make sure we do not create a negative payment too
            
            # Adjust a payment
            payment_key_part = Regexp.new("^#{person[:legacy_id]}/#{record.trnscdyr}")
            
            matches = @payments.keys.select { |v| v =~ payment_key_part }
            matches.reverse!
            
            remaining_amount = record.trnsamnt.to_f.abs
            # puts "#{person[:legacy_id]}/#{record.trnscdyr} : Start #{remaining_amount}"
            matches.each do |key|
              payment = @payments[key]
              if payment[:payment_amount].to_f >= remaining_amount
                
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : PAYMENT #{payment[:payment_amount].to_f }"
                
                allocations_to_delete = @allocations.select { |a| a[:payment_id] == payment[:legacy_id] }
                billing_id = ''
                allocations_to_delete.each do |allocation|
                  billing_id = allocation[:billing_id]
                  @allocations.delete(allocation)
                end
                
                if billing_id.blank?
                  display_warn "AdjustP", "No allocation to remove : #{person[:legacy_id]}/#{record.trnscdyr} for amount #{record.trnsamnt}"
                  break
                end
                
                payment[:payment_amount] = payment[:payment_amount].to_f - remaining_amount
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : AFTER #{payment[:payment_amount]}"
                
                if payment[:payment_amount].to_f == 0
                  # puts "#{person[:legacy_id]}/#{record.trnscdyr} : DELETE"
                  @payments.delete(payment[:legacy_id])
                else                
                  # Do a new allocation to replace the deleted one
                  @allocations << Allocation.new(
                    payment_id: payment[:legacy_id],
                    billing_id: billing_id,
                    allocation_amount: payment[:payment_amount].to_f 
                  )
                  # puts "#{person[:legacy_id]}/#{record.trnscdyr} : ALLOCATE #{payment[:payment_amount].to_f}"
                end
                
                count_adjusted += 1
                remaining_amount = 0 # Its done
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : REMAINING #{remaining_amount}"
                break
              else
                # Latest payment is < remaining amount, nuke it and reduce the remaining
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : PAYMENT* #{payment[:payment_amount].to_f }"
                
                allocations_to_delete = @allocations.select { |a| a[:payment_id] == payment[:legacy_id] }
                allocations_to_delete.each do |allocation|
                  @allocations.delete(allocation)
                end
                
                remaining_amount = remaining_amount - payment[:payment_amount].to_f
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : DELETE"
                # puts "#{person[:legacy_id]}/#{record.trnscdyr} : REMAINING #{remaining_amount}"
                @payments.delete(payment[:legacy_id])
                count_adjusted += 1
              end
            end
            
            if remaining_amount > 0
              display_warn "Deposit", "Not all payments adjusted : #{person[:legacy_id]}/#{record.trnscdyr} for amount #{record.trnsamnt}"
            end
          end
        end
        display_count({"Found" => count_found, "Created" => count_created, "Adjusted" => count_adjusted})
      end
      
      # -------------------------------------------------------------------------

      def generate_deposit_payment_allocations_for_contributions
        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_for_contributions "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}", process_year
          process_year += 1
        end
        
        generate_for_contributions "Current YTD", "#{@folder.path}/ESRBYTD.DBF", Date.today.year
      end
      
      def generate_for_contributions(which, file_path, year)
        display_action "Pass 4", "#{which} Deposits, Payments and Allocations (C)"
        
        table = DBF::Table.new(file_path)
        count_found = 0
        count_created = 0
        billing_found = 0
        billing_created = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'C'
          next if record.trnsamnt.to_f < 0
          next if record.bnum.blank? # Ignore carry forwards
          
          count_found += 1
          
          deposit = find_or_create_deposit(record.bnum, record.trnsdate)
          if deposit.nil?
            display_fail "Deposit", "Batch not found : #{record.bnum}"
            next
          end
          
          # Make a payment...
          person = @people[record.acctnum]
          if person.nil?
            display_fail "Deposit", "Person not found, unable to save payment : #{record.acctnum}"
            next
          end
          
          # Special case in contributions, find the billing, if not create a sonation billing 
          # to match the amount
          
          event = @events[Helper::to_legacy_id(record.trnscdyr)]
          if event.nil?
            # Only log errors for those after import period
            unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
              display_warn "Allocation", "Event not found, unable to allocate : #{record.trnscdyr}"
            end
            next
          end
          
          billing_key_part = "#{person[:legacy_id]}/#{event[:legacy_id]}"
          # Try for an attendance first
          billing = @billings[billing_key_part + "/A"]
          if billing.nil?
            # See if we have a donation billing?
            billing = @billings[billing_key_part + "/D"]
            if billing.nil?
              # Make a new donation billing...
              add_attending(record, false) # In case its not there (does not increment attending count)
              add_billing(record, 'Donation')
              billing = @billings[billing_key_part + "/D"]
              billing_created += 1
            else
              # Need to increase the donation billing amount for the next payment...
              billing[:bill_amount] = billing[:bill_amount].to_f + record.trnsamnt
              billing[:payable_amount] = billing[:payable_amount].to_f + record.trnsamnt
              billing_found += 1
            end
          else
            billing_found += 1
          end
          
          payment = Payment.new(
            legacy_id: "#{person[:legacy_id]}/#{record.trnscdyr}/#{@payments.keys.count}/PC",
            deposit_id: deposit[:legacy_id],
            person_id: person[:legacy_id],
            kind: 'Check',
            # reference_code: '',
            payment_amount: record.trnsamnt,
            allocated_amount: 0.0,
            note: record.comment.gsub(/"/, "'"),
            # third_party_id: '',
            # honor: '',
            # honoree: '',
            # notify_id: '',
            # decline_date: '',
            # decline_posted: false,
            # refund_amount: 0
          )
          @payments[payment[:legacy_id]] = payment
                    
          # Allocate to the attendance billing
          @allocations << Allocation.new(
            payment_id: payment[:legacy_id],
            billing_id: billing[:legacy_id],
            allocation_amount: record.trnsamnt
          )
          count_created += 1
        end
        
        display_count({"Found" => count_found, "Created" => count_created, "Billings" => billing_found, "BCreated" => billing_created})
      end
      
      # -------------------------------------------------------------------------

      def adjust_billings
        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_for_adjustments "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}", process_year
          process_year += 1
        end
        
        generate_for_adjustments "Current YTD", "#{@folder.path}/ESRBYTD.DBF", Date.today.year
      end
      
      def generate_for_adjustments(which, file_path, year)
        display_action "Pass 5", "#{which} Adjust Billings (V)"
        
        table = DBF::Table.new(file_path)
        count_found = 0
        count_adjusted = 0
        count_deleted = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'V'
          next if record.trnsamnt.to_f > 0
          next if record.bnum.blank? # Ignore carry forwards
          
          count_found += 1
          
          person = @people[record.acctnum]
          if person.nil?
            display_fail "Adjustment", "Person not found, unable to save adjustment : #{record.acctnum}"
            next
          end
          
          event = @events[Helper::to_legacy_id(record.trnscdyr)]
          if event.nil?
            # Only log errors for those after import period
            unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
              display_warn "Adjustment", "Event not found, unable to adjust : #{record.trnscdyr}"
            end
            next
          end
          
          # If its a DEBIT, adjust a billing
          if record.dbcrcode == 'D'
            # Adjust a billing
            billing_key_part = "#{person[:legacy_id]}/#{event[:legacy_id]}"
            # Try for an attendance first
            billing = @billings[billing_key_part + "/A"]
            if billing.nil?
              # See if we have a donation billing?
              billing = @billings[billing_key_part + "/D"]
            end

            if billing.nil?
              display_fail "Adjustment", "No billing to adjust : #{billing_key_part}"
              next
            end

            # We have a billing, yay
            payable = billing[:payable_amount].blank? ? billing[:bill_amount].to_f : billing[:payable_amount].to_f
            new_payable = payable - record.trnsamnt.to_f.abs
            
            if new_payable == 0

              allocations_to_delete = []
              @allocations.each do |allocation|
                if allocation[:billing_id] == billing[:legacy_id]
                  allocations_to_delete << allocation
                end
              end
            
              allocations_to_delete.each do |allocation|
                @allocations.delete(allocation)
              end
              
              # Reduce the attending so the bill_for is right
              attending = @attendings["#{person[:legacy_id]}/#{event[:legacy_id]}"]
              if attending.present?
                if attending[:no_of].to_i > 1
                  attending[:no_of] = attending[:no_of].to_i - 1
                end
              end
              
              @billings.delete(billing[:legacy_id])
              count_deleted += 1              
            else
              # Its a reduction, not a nuke
              
              # Reduce the attending so the bill_for is right
              attending = @attendings["#{person[:legacy_id]}/#{event[:legacy_id]}"]
              if attending.present?
                if attending[:no_of].to_i > 1
                  attending[:no_of] = attending[:no_of].to_i - 1
                end
              end
              
              billing[:payable_amount] = new_payable
              count_adjusted += 1
            end
          else
            # Adjust a payment
            payment_key_part = Regexp.new("^#{person[:legacy_id]}/#{record.trnscdyr}")
            
            matches = @payments.keys.select { |v| v =~ payment_key_part }
            
            matched = false
            matches.each do |key|
              payment = @payments[key]
              if payment[:payment_amount].to_f == record.trnsamnt.to_f.abs
                # puts "NUKE #{person[:legacy_id]} on #{payment[:legacy_id]} for #{record.trnsamnt.to_f}..."
                
                allocations_to_delete = @allocations.select { |a| a[:payment_id] == payment[:legacy_id] }
            
                allocations_to_delete.each do |allocation|
                  @allocations.delete(allocation)
                end
                
                @payments.delete(payment[:legacy_id])
                count_deleted += 1
                matched = true
                break
              end
            end
            
            if matched == false
              display_warn "Adjustment", "No payment to adjust : #{person[:legacy_id]}/#{record.trnscdyr} for amount #{record.trnsamnt}"
            end
          end
        end
        display_count({"Found" => count_found, "Adjusted" => count_adjusted, "Deleted" => count_deleted})
      end

      # -------------------------------------------------------------------------      
      
      def generate_reallocations
        # Older files...
        process_year = @import_start_date.year + 1
        while process_year < Date.today.year
          extension = Helper::get_f_extension(process_year)
          generate_for_realloc "Year #{process_year}", "#{@folder.path}/ESRBYTD.#{extension}", process_year
          process_year += 1
        end
        
        generate_for_realloc "Current YTD", "#{@folder.path}/ESRBYTD.DBF", Date.today.year
      end
      
      def generate_for_realloc(which, file_path, year)
        display_action "Pass 6", "#{which} Reallocations (A)"
        
        table = DBF::Table.new(file_path)
        count_found = 0
        count_adjusted = 0
        count_deleted = 0
        table.each do |record|
          next if record.nil?
          next unless record.trnstype == 'A'
          next if record.trnsamnt.to_f < 0
          next if record.bnum.blank? # Ignore carry forwards
          
          count_found += 1
          
          # No idead how to find the matching payment and reallocate
          # So FAIL
          person = @people[record.acctnum]
          if person.nil?
            display_fail "Realloc", "Person not found, unable to save adjustment : #{record.acctnum}"
            next
          end
          
          event = @events[Helper::to_legacy_id(record.trnscdyr)]
          if event.nil?
            # Only log errors for those after import period
            unless Helper::to_legacy_year(record.trnscdyr) < @import_start_year
              display_fail "Realloc", "Event not found, unable to adjust : #{record.trnscdyr}"
            end
            next
          end
          
          display_fail "Realloc", "Unable to match payments and reallocate : #{person[:legacy_id]}/#{record.trnscdyr} for amount #{record.trnsamnt}"
        end
      end
      
      # -------------------------------------------------------------------------
      
      def find_or_create_deposit(batch_code, trnsdate)
        return @deposits[batch_code] unless @deposits[batch_code].nil?
        
        if batch_code.length == 4 && batch_code.to_i != 0
          # Must be a batch that is not in the file, so create one
          batch = @temp_batches[batch_code]
          
          unless batch.nil?
            deposit = Deposit.new(
              legacy_id: batch[:legacy_id],
              deposit_date: batch[:batch_date],
              bank_account_id: @marks["deposit_bank_account_code"]
            )
            if deposit.valid?
              @deposits[deposit[:legacy_id]] = deposit
              return deposit
            else
              display_fail "Deposit", "#{deposit.errors.join(', ')} : #{deposit[:legacy_id]}"
              return nil
            end
          else
            display_fail "Deposit", "Batch not found : #{deposit[:legacy_id]}"
            return nil            
          end
        end
        
        # Here on the zero codes
        the_date = Helper::marks_to_iso_date(trnsdate)
        new_key = "DEP-#{the_date.to_s}"
        
        return @deposits[new_key] unless @deposits[new_key].nil?
        
        # Ok create it
        deposit = Deposit.new(
          legacy_id: new_key,
          deposit_date: the_date,
          bank_account_id: @marks["deposit_bank_account_code"]
        )
        if deposit.valid?
          @deposits[deposit[:legacy_id]] = deposit
          return deposit
        else
          display_fail "Deposit", "#{deposit.errors.join(', ')} : #{deposit[:legacy_id]}"
          return nil
        end
      end
      
      # -------------------------------------------------------------------------
      
      def write_files
        File.open("#{@dest.path}/config.json", "w") {|f| f.write(@config.to_json) }
        
        write_hash_file "chart_accounts", @chart_accounts, ChartAccount.new().header
        write_hash_file "tags", @tags, Tag.new().header
        write_hash_file "occupations", @occupations, Occupation.new().header
        write_hash_file "people", @people, Person.new().header
        
        write_array_file "relationships", @relationships, Relationship.new().header
        write_array_file "person_milestones", @person_milestones, PersonMilestone.new().header
        write_array_file "person_tags", @person_tags, PersonTag.new().header
        write_array_file "addresses", @addresses, Address.new().header
        write_array_file "phones", @phones, Phone.new().header
        write_array_file "emails", @emails, Email.new().header
        
        write_hash_file "events", @events, Event.new().header
        write_hash_file "attendings", @attendings, Attending.new().header
        write_hash_file "billings", @billings, Billing.new().header
        write_hash_file "deposits", @deposits, Deposit.new().header
        write_hash_file "payments", @payments, Payment.new().header
        write_array_file "allocations", @allocations, Allocation.new().header
      end
      
      def write_hash_file(name, a_hash, header)
        File.open("#{@dest.path}/#{name}.csv", "w") do |f|
          f.puts header
          a_hash.values.each do |item|
            f.puts item.to_csv
          end
        end
      end

      def write_array_file(name, a_array, header)
        File.open("#{@dest.path}/#{name}.csv", "w") do |f|
          f.puts header
          a_array.each do |item|
            f.puts item.to_csv
          end
        end
      end
      
      # -------------------------------------------------------------------------
      
      def display_start
        display_heading "Starting", "Marks Import"
        display_item "Start From", @import_start_date
      end
      
      def display_end
        display_heading "Statistics", "Marks Import"
        
        display_item "Chart Accounts", "#{@chart_accounts.keys.length}"
        display_item "Tags", "#{@tags.keys.length}"
        display_item "Occupations", "#{@occupations.keys.length}"
        display_item "People", "#{@people.keys.length}"
        display_item "Relationships", "#{@relationships.length}"
        display_item "Milestones", "#{@person_milestones.length}"
        display_item "Person Tags", "#{@person_tags.length}"
        display_item "Addresses", "#{@addresses.length}"
        display_item "Phones", "#{@phones.length}"
        display_item "Emails", "#{@emails.length}"
        display_item "Events", "#{@events.keys.length}"
        display_item "Attendings", "#{@attendings.keys.length}"
        display_item "Billings", "#{@billings.keys.length}"
        display_item "Deposits", "#{@deposits.keys.length}"
        display_item "Payments", "#{@payments.keys.length}"
        display_item "Allocations", "#{@allocations.length}"
        
        # display_item "Marks Import", "Done"
        @file.close
      end
      
    end
    
  end
end