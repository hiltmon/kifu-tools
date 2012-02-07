require 'dbf'

module Kifu
  module Tools

    class MarksImport
      
      def initialize(folder)
        raise "[#{folder}] is not a directory path" unless File.directory?(folder)
        raise "[#{folder}] does not contain MARKS files" unless File.exists?("#{folder}/ESWSLNK1.DBF")
        @folder = Dir.new(folder)
        
        @people = {}
        @relationships = []
        @person_milestones = []
      end
      
      def perform
        display_start
        
        generate_people_file
        
        display_end
      end
      
      private
    
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
          gender: MarksHelper::gender(record.title1, record.codes[2]) # Code 2 is person 1 gender
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
        else
          puts Color.red("  Invalid ") + Color.magenta("Person") + Color.red(": #{person.errors.join(', ')} : #{person[:legacy_id]} #{person[:last_name]}, #{person[:first_name]} ")
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
          gender: MarksHelper::gender(record.title2, record.codes[3]) # Code 3 is person 1 gender 
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
          puts Color.red("  Invalid ") + Color.magenta("Spouse") + Color.red(": #{spouse.errors.join(', ')} : #{person[:legacy_id]} #{spouse[:last_name]}, #{spouse[:first_name]} ")
          return nil
        end      
        
        spouse
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
        puts "         People: " + Color.green("#{@people.keys.length}")
        puts "  Relationships: " + Color.green("#{@relationships.length}")
        puts "     Milestones: " + Color.green("#{@person_milestones.length}")
        puts Color.yellow("Marks Import ") + Color.green("Done...")
      end
      
    end
    
  end
end