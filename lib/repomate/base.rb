require_relative 'configuration'
require_relative 'architecture'
require_relative 'repository'
require_relative 'metafile'
require_relative 'package'
require 'date'
require 'time'

module RepoMate
  class Base

    def initialize
      @config     = Configuration.new
      @repository = Repository.new
      @metafile   = Metafile.new
      @logdir     = @config.get[:logdir]

      FileUtils.mkdir_p(@logdir) unless Dir.exists?(@logdir)
    end

    def redolog
      File.join(@config.get[:logdir], @config.get[:redolog])
    end

    def stage(workload)
      workload.each do |entry|
        package     = Package.new(entry[:package_fullname], entry[:suitename], entry[:component])
        destination = Component.new(entry[:component], entry[:suitename], "stage")

        @repository.create(entry[:suitename], entry[:component])

        FileUtils.copy(entry[:package_fullname], File.join(destination.directory, package.newbasename))
      end
    end

    def prepare_publish
      workload = []

      source_category      = "stage"
      destination_category = "pool"

      Component.allabove(source_category).each do |entry|
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

    def publish(workload)
      newworkload = []
      workload.each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
        basename    = File.split(entry[:source_fullname])[1]

        puts "Package: #{basename} publishing"
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
      link(workload)
    end

    def link(workload)
      dpkg   = @config.get[:dpkg]

      # raise "dpkg is not installed" unless File.exists?(dpkg)

      link   = []
      unlink = []
      action = false

      workload.each do |entry|
        source_package       = Package.new(entry[:source_fullname], entry[:suitename], entry[:component])
        destination_fullname = File.join(entry[:destination_dir], source_package.newbasename)

        Dir.glob("#{entry[:destination_dir]}/#{source_package.name}*.deb") do |target_fullname|
          target_package = Package.new(destination_fullname, entry[:suitename], entry[:component] )

         # if system("#{dpkg} --compare-versions #{source_package.version} gt #{target_package.version}")
            puts "Package: #{target_package.newbasename} will be replaced with #{source_package.newbasename}"
            unlink << {
              :destination_fullname => target_fullname,
              :newbasename          => target_package.newbasename
            }
          # elsif system("#{dpkg} --compare-versions #{source_package.version} eq #{target_package.version}")
          # puts "Package: #{source_package.newbasename} already exists with same version"
          # elsif system("#{dpkg} --compare-versions #{source_package.version} lt #{target_package.version}")
          # puts "Package: #{source_package.newbasename} already exists with higher version"
          # end
        end

        link << {
          :source_fullname      => entry[:source_fullname],
          :destination_fullname => destination_fullname,
          :suitename            => entry[:suitename],
          :component            => entry[:component],
          :newbasename          => source_package.newbasename
        }
      end

      unlink.each do |entry|
        File.unlink(entry[:destination_fullname])
        puts "Package: #{entry[:newbasename]} unlinked"
        action = true
      end

      link.each do |entry|
        unless File.exists?(entry[:destination_fullname])
          File.symlink(entry[:source_fullname], entry[:destination_fullname])
          puts "Package: #{entry[:newbasename]} linked to production => #{entry[:suitename]}/#{entry[:component]}"
          action = true
        end
      end

      if action
        @metafile.create
      end
    end

    def save_checkpoint
      datetime        = DateTime.now
      source_category = "dists"

      File.open(redolog, 'a') do |file|
        Architecture.allabove(source_category).each do |entry|
          source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
          source.files.each do |fullname|
            basename = File.basename(fullname)
            file.puts "#{datetime} #{entry[:suitename]} #{entry[:component]} #{entry[:architecture]} #{basename}"
          end
        end
      end

      puts "Checkpoint (#{datetime.strftime("%F %T")}) saved"
    end

    def load_checkpoint(number)
      list            = get_checkpoints
      workload        = []
      source_category = "dists"

      Architecture.allabove(source_category).each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
        destination.files.each do |fullname|
          File.unlink fullname
        end
      end

      File.open(redolog, 'r') do |file|
        while (line = file.gets)
          if line.split[0] == list[number]
            suitename    = line.split[1]
            component    = line.split[2]
            architecture = line.split[3]
            basename     = line.split[4]
            source       = Architecture.new(architecture, component, suitename, "pool")
            destination  = Architecture.new(architecture, component, suitename, "dists")

            workload << {
              :source_fullname  => File.join(source.directory, basename),
              :destination_dir  => destination.directory,
              :component        => component,
              :suitename        => suitename,
              :architecture     => architecture
            }
          end
        end
      end

      link(workload)
    end

    def get_checkpoints
      unless File.exists?(redolog)
        puts "We can't restore because we don't have checkpoints"
        exit 1
      end

      order = 0
      dates = []
      list  = {}

      File.open(redolog, 'r') do |file|
        while (line = file.gets)
          dates << line.split[0] unless dates.include?(line.split[0])
        end
      end

      dates.each do |date|
        order += 1
        list[order] = date
      end

      list
    end

    def get_packagelist(category)
      packages = []

      Architecture.allabove(category).each do |entry|
        source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], category)
        source.files.each do |fullname|
          package = Package.new(fullname, entry[:suitename], entry[:component])

          packages << {
            :fullname    => fullname,
            :controlfile => package.controlfile,
            :component   => entry[:component],
            :suitename   => entry[:suitename],
          }
        end
      end
      packages
    end
  end
end
