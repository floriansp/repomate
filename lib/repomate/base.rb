require 'repomate'
require 'date'
require 'time'
require 'colors'

# RepoMate module
module RepoMate

  # Class containing the main logic
  class Base

    # Init
    def initialize
      FileUtils.mkdir_p(Cfg.rootdir)

      @repository = Repository.new
      @metafile   = Metafile.new
      @cpdbfile   = File.join(Cfg.rootdir, "checkpoints.db")
      @cpdb       = Database.new(@cpdbfile)

      unless Dir.exists?(Cfg.logdir)
        puts
        puts "\tPlease run \"repomate setup\" first!".hl(:red)
        puts
      end

      create_checkpoints_table

    end

    # Add's a package to the staging area
    def stage(workload)
      workload.each do |entry|
        @repository.create(entry[:suitename], entry[:component])

        package     = Package.new(entry[:package_fullname], entry[:suitename], entry[:component])
        destination = Component.new(entry[:component], entry[:suitename], "stage")

        FileUtils.copy(entry[:package_fullname], File.join(destination.directory, package.newbasename))
      end
    end

    # Returns a list of staged packages for cli confirmation packed as array of hashes
    def prepare_publish
      workload = []

      source_category      = "stage"
      destination_category = "pool"

      Component.dataset(source_category).each do |entry|
        source = Component.new(entry[:component], entry[:suitename], source_category)
        source.files.each do |fullname|
          package     = Package.new(fullname, entry[:suitename], entry[:component])
          destination = Architecture.new(package.architecture, entry[:component], entry[:suitename], destination_category)

          workload << {
            :source_fullname      => fullname,
            :destination_fullname => File.join(destination.directory, package.newbasename),
            :component            => entry[:component],
            :suitename            => entry[:suitename],
            :architecture         => package.architecture
          }
        end
      end
      workload
    end

    # Publish all staged packages. Packages will be moved from stage to pool and linked to dists
    def publish(workload)
      newworkload = []
      workload.each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
        basename    = File.basename(entry[:source_fullname])

        @repository.create(entry[:suitename], entry[:component], entry[:architecture])

        newworkload << {
          :source_fullname => entry[:destination_fullname],
          :destination_dir => destination.directory,
          :component       => entry[:component],
          :suitename       => entry[:suitename],
          :architecture    => entry[:architecture]
        }
        FileUtils.move(entry[:source_fullname], entry[:destination_fullname])
      end
      workload = newworkload

      save_checkpoint
      check_versions(workload)
    end

    # Does the link job after checking versions through dpkg
    def check_versions(workload)
      dpkg = Cfg.dpkg

      raise "dpkg is not installed" unless File.exists?(dpkg)

      link_workload   = []
      unlink_workload = []

      workload.each do |entry|
        source_package       = Package.new(entry[:source_fullname], entry[:suitename], entry[:component])
        destination_fullname = File.join(entry[:destination_dir], source_package.newbasename)

        Dir.glob("#{entry[:destination_dir]}/#{source_package.name}*.deb") do |target_fullname|
          target_package = Package.new(target_fullname, entry[:suitename], entry[:component] )

          if system("#{dpkg} --compare-versions #{source_package.version} gt #{target_package.version}")
            puts "Package: #{target_package.newbasename} will be replaced with #{source_package.newbasename}"
            unlink_workload << {
              :destination_fullname => target_fullname,
              :newbasename          => target_package.newbasename
            }
          elsif system("#{dpkg} --compare-versions #{source_package.version} eq #{target_package.version}")
            puts "Package: #{source_package.newbasename} already exists with same version"
            return
          elsif system("#{dpkg} --compare-versions #{source_package.version} lt #{target_package.version}")
            puts "Package: #{source_package.newbasename} already exists with higher version"
            return
          end
        end

        link_workload << {
          :source_fullname      => source_package.fullname,
          :destination_fullname => destination_fullname,
          :suitename            => source_package.suitename,
          :component            => source_package.component,
          :newbasename          => source_package.newbasename
        }
      end

      unlink(unlink_workload)
      link(link_workload)
    end

    # links the workload
    def link(workload)
      action = false

      workload.each do |entry|
        @repository.create(entry[:suitename], entry[:component], entry[:architecture])
        unless File.exists?(entry[:destination_fullname])
          package = Package.new(entry[:source_fullname], entry[:suitename], entry[:component])
          package.create_checksums

          File.symlink(entry[:source_fullname], entry[:destination_fullname])
          puts "Package: #{package.newbasename} linked to production => #{entry[:suitename]}/#{entry[:component]}"
          action = true
        end
      end

      if action
        @metafile.create
      end
    end

    # unlinks workload
    def unlink(workload)
      action = false

      workload.each do |entry|
        package = Package.new(entry[:destination_fullname], entry[:suitename], entry[:component])
        package.delete_checksums

        File.unlink(entry[:destination_fullname])
        puts "Package: #{package.newbasename} unlinked"
        action = true
      end

      if action
        cleandirs
        @metafile.create
      end
    end

    # Create the checkpoint table
    def create_checkpoints_table
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
    def save_checkpoint
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
    def load_checkpoint(number)
      list            = get_checkpoints
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
        if row[0] == list[number]
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

      unlink(unlink_workload)
      link(link_workload)
    end

    # Returns a list of checkpoints for the cli
    def get_checkpoints
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

    # Returns a list of packages
    def get_packagelist(category)
      packages = []
      if category.eql?("stage")
        Component.dataset(category).each do |entry|
          source = Component.new(entry[:component], entry[:suitename], category)
          source.files.each do |fullname|
            package = Package.new(fullname, entry[:suitename], entry[:component])

            packages << {
              :fullname    => fullname,
              :controlfile => package.controlfile,
              :component   => entry[:component],
              :suitename   => entry[:suitename]
            }
          end
        end
      else
        Architecture.dataset(category).each do |entry|
          source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], category)
          source.files.each do |fullname|
            package = Package.new(fullname, entry[:suitename], entry[:component])

            packages << {
              :fullname     => fullname,
              :controlfile  => package.controlfile,
              :component    => entry[:component],
              :suitename    => entry[:suitename],
              :architecture => entry[:architecture]
            }
          end
        end
      end
      packages
    end

    # cleans up unused directories
    def cleandirs
      action = false

      @repository.categories.each do |category|
        next if category.eql?("stage")
        Architecture.dataset(category).each do |entry|
          directory = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], category)
          if directory.is_unused?(entry[:fullpath])
            action = true
            directory.destroy
          end
        end
        Component.dataset(category).each do |entry|
          directory = Component.new(entry[:component], entry[:suitename], category)
          if directory.is_unused?(entry[:fullpath])
            action = true
            directory.destroy
          end
        end
        Suite.dataset(category).each do |entry|
          directory = Suite.new(entry[:suitename], category)
          if directory.is_unused?(entry[:fullpath])
            action = true
            directory.destroy
          end
        end
      end
      if action
        puts "Cleaning structure"
        @metafile.create
      end
    end
  end
end

