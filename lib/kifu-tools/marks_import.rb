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
        @people = {}
        @relationships = []
        @person_milestones = []
        @person_tags = []
        @addresses = []
        @phones = []
      end
      
      def perform
        display_start
        
        generate_tag_file
        generate_people_file
        
        display_end
      end
      
      private
      
      def generate_tag_file
        unless @config["tags"].nil?
          @config["tags"].each_pair do |key, value|
            @tags[key] = Tag.new(
              legacy_id: key,
              tag: value[:name],
              implies: value[:implies]
            )
          end
        end
      end
    
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
        
        puts person[:account_since]
          
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
          generate_phone(record.hphone1, person, true)
          generate_phone(record.hphone2, person, false)
          
          # Tag em
          unless record.codes[0].nil? || record.codes[0] == '' || record.codes[0] == ' '
            person_tag = PersonTag.new(
              person_legacy_id: person[:legacy_id],
              tag_legacy_id: @tags[record.codes[0]]
            )
            if person_tag.valid?
              @person_tags << person_tag
            else
              puts Color.cyan("  WARN ") + "PersonTag" + Color.cyan(": #{person_tag.errors.join(', ')} : #{person.description} (Tag is #{record.codes[0]})")
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
          generate_relationship('Spouse', spouse, person)
              
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
      
      def generate_phone(field, person, pref)
        unless field == ''
          if field =~ /\d\d\d.\d\d\d/
            phone = Phone.new(
              person_legacy_id: person[:legacy_id],
              kind: 'home',
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

        r2 = Relationship.new(
          person_legacy_id: relative[:legacy_id],
          spouse_legacy_id: person[:legacy_id],
          relationship: Helper::relationship(kind, relative[:gender], person[:gender])
        )
        @relationships << r2
      end
      
      def display_start
        puts Color.yellow("Marks Import ") + Color.green("Starting...")
      end
      
      def display_end
        puts Color.yellow("Marks Import Statistics")
        puts "           Tags: " + Color.green("#{@tags.keys.length}")
        puts "         People: " + Color.green("#{@people.keys.length}")
        puts "  Relationships: " + Color.green("#{@relationships.length}")
        puts "     Milestones: " + Color.green("#{@person_milestones.length}")
        puts "    Person Tags: " + Color.green("#{@person_tags.length}")
        puts "      Addresses: " + Color.green("#{@addresses.length}")
        puts "         Phones: " + Color.green("#{@phones.length}")
        puts Color.yellow("Marks Import ") + Color.green("Done...")
      end
      
    end
    
  end
end