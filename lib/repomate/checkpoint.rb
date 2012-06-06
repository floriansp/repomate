require 'repomate'
require 'date'
require 'time'

# RepoMate module
module RepoMate

  # Class containing the main logic
  class Checkpoint

    # Init
    def initialize
      @link       = Link.new
      @cpdbfile   = File.join(Cfg.rootdir, "checkpoints.db")
      @cpdb       = Database.new(@cpdbfile)

      create_table
    end

    # Create the checkpoint table
    def create_table
      sql = "create table if not exists checkpoints (
              date varchar(25),
              suitename varchar(10),
              component varchar(10),
              architecture varchar(10),
              basename varchar(70)
      )"
      @cpdb.query(sql)
    end

    # Saves a checkpoint
    def create
      datetime        = DateTime.now
      source_category = "dists"

      Architecture.dataset(source_category).each do |entry|
        source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
        source.files.each do |fullname|
          basename = File.basename(fullname)
          @cpdb.query("insert into checkpoints values ( '#{datetime}', '#{entry[:suitename]}', '#{entry[:component]}', '#{entry[:architecture]}', '#{basename}' )")
        end
      end

      puts "Checkpoint (#{datetime.strftime("%F %T")}) saved"
    end

    # Loads a checkpoint
    def load(number)
      cplist          = list
      link_workload   = []
      unlink_workload = []
      source_category = "dists"

      Architecture.dataset(source_category).each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
        destination.files.each do |fullname|
          unlink_workload << {
            :destination_fullname => fullname,
            :component            => entry[:component],
            :suitename            => entry[:suitename],
            :architecture         => entry[:architecture]
          }
        end
      end

      @cpdb.query("select date, suitename, component, architecture, basename from checkpoints").each do |row|
        if row[0] == cplist[number]
            suitename    = row[1]
            component    = row[2]
            architecture = row[3]
            basename     = row[4]
            source       = Architecture.new(architecture, component, suitename, "pool")
            destination  = Architecture.new(architecture, component, suitename, "dists")

            link_workload << {
              :source_fullname      => File.join(source.directory, basename),
              :destination_fullname => File.join(destination.directory, basename),
              :component            => component,
              :suitename            => suitename,
              :architecture         => architecture
            }
        end
      end

      @link.destroy(unlink_workload)
      @link.create(link_workload)
    end

    # Deletes a package from checkpoint table
    def delete_package(package)
      @cpdb.query("delete from checkpoints where basename = '#{package[:basename]}' and suitename = '#{package[:suitename]}' and component = '#{package[:component]}' and architecture = '#{package[:architecture]}'")
    end

    # Returns a list of checkpoints for the cli
    def list
      order = 0
      dates = []
      list  = {}

      @cpdb.query("select date from checkpoints group by date order by date asc").each do |row|
        dates << row.first
      end

      dates.each do |date|
        order += 1
        list[order] = date
      end

      list
    end
  end
end
