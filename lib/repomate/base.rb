require_relative 'configuration'
require_relative 'architecture'
require_relative 'repository'
require_relative 'package'
require 'date'
require 'time'
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module RepoMate
  class Base

    def initialize
      @config     = Configuration.new
      @repository = Repository.new
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

      @repository.loop("stage").each do |entry|
        source = Component.new(entry[:component], entry[:suitename], "stage")
        source.files.each do |fullname|
          package     = Package.new(fullname, entry[:suitename], entry[:component])
          destination = Architecture.new(package.architecture, entry[:component], entry[:suitename], "pool")

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
        File.symlink(entry[:source_fullname], entry[:destination_fullname]) unless File.exists?(entry[:destination_fullname])
        puts "Package: #{entry[:newbasename]} linked to production => #{entry[:suitename]}/#{entry[:component]}"
        action = true
      end

      if action
        scan_packages
      end
    end

    def scan_packages
      @repository.loop("dists").each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")

        packages    = File.join(destination.directory, "Packages")
        packages_gz = File.join(destination.directory, "Packages.gz")

        File.unlink(packages) if File.exists?(packages)

        destination.files.each do |fullname|
          package = Package.new(fullname, entry[:suitename], entry[:component])

          File.open(packages, 'a') do |file|
            package.controlfile.each do |key, value|
              file.puts "#{key}: #{value}"
            end

            # temp
            size = File.size(fullname)

            file.puts "Size: #{size}"
            file.puts "Filename: dists/#{entry[:suitename]}/#{entry[:component]}/#{entry[:architecture_dir]}/#{package.newbasename}"
            file.puts "MD5sum: #{Digest::MD5.file(fullname).to_s}"
            file.puts "SHA1: #{Digest::SHA1.file(fullname).to_s}"
            file.puts "SHA256: #{Digest::SHA256.new(256).file(fullname).to_s}\n\n"
          end
        end
        if File.exists?(packages)
          raise "Could not gzip" unless system "gzip -9 -c #{packages} > #{packages_gz}"
        end
      end

      release          = "Release"
      origin           = @config.get[:origin]
      label            = @config.get[:label]
      suites           = []
      components       = []
      architectures    = []
      architecturedirs = []


      @repository.loop("dists").each do |entry|
        source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")

        suites << entry[:suitename] unless suites.include?(entry[:suitename])
        components << entry[:component] unless components.include?(entry[:component])
        architectures << entry[:architecture] unless architectures.include?(entry[:architecture])
        architecturedirs << entry[:architecture_dir] unless architecturedirs.include?(entry[:architecture_dir])

        File.open(File.join(source.directory, release), 'w') do |file|
          file.puts "Archive: stable"
          file.puts "Component: #{entry[:component]}"
          file.puts "Origin: #{origin}"
          file.puts "Label: #{label}"
          file.puts "Architecture: #{entry[:architecture]}"
          file.puts "Description: Repository for debian #{entry[:suitename]}"
        end
      end

      dt = Time.new.strftime("%a, %d %b %Y %H:%M:%S %Z")

      suitesline = suites.join ', '
      componentline = components.join ', '
      architectureline = architectures.join ', '

      suites.each do |suite|
        source = Suite.new(suite, "dists")

        File.open(File.join(source.directory, release), 'w') do |file|
          file.puts "Origin: #{origin}"
          file.puts "Label: #{label}"
          file.puts "Suite: stable"
          file.puts "Codename: #{source.name}"
          file.puts "Date: #{dt}"
          file.puts "Architectures: #{architectureline}"
          file.puts "Components: #{componentline}"
          file.puts "Description: Repository for debian #{suitesline}"
          file.puts "MD5Sum:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::MD5.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::MD5.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end

          file.puts "SHA1:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end

          file.puts "SHA256:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA256.new(256).file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA256.new(256).file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end
        end
      end

      # Add something like gpg -a --yes -u $KEY -b -o dists/squeeze/Release.gpg dists/squeeze/Release here

    end

    def save_checkpoint
      datetime = DateTime.now
      File.open(redolog, 'a') do |file|
        @repository.loop("dists").each do |entry|
          source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
          source.files.each do |fullname|
            basename = File.basename(fullname)
            file.puts "#{datetime} #{entry[:suitename]} #{entry[:component]} #{entry[:architecture]} #{basename}"
          end
        end
      end

      puts "Checkpoint (#{datetime.strftime("%F %T")}) saved"
    end

    def load_checkpoint(number)
      list      = get_checkpoints
      workload  = []

      @repository.loop("dists").each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
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

      @repository.loop(category).each do |entry|
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

