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
            file.puts "MD5sum: #{Digest::MD5.file(fullname).to_s}"
            file.puts "SHA1: #{Digest::SHA1.file(fullname).to_s}"
            file.puts "SHA256: #{Digest::SHA256.new(256).file(fullname).to_s}\n\n"
          end
        end
        if File.exists?(packages)
          raise "Could not gzip" unless system "gzip -9 -c #{packages} > #{packages_gz}"
        end
      end


      # Archive: unstable
      # Component: main
      # Origin: XING squeeze repo
      # Label: XING squeeze repo
      # Architecture: amd64
      # Description: a debian squeeze based repository for XING software
      release         = "Release"
      origin          = @config.get[:origin]
      label           = @config.get[:label]
      suites          = []
      components      = []
      architectures   = []
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

      # Origin: XING squeeze repo
      # Label: XING squeeze repo
      # Suite: unstable
      # Codename: squeeze
      # Date: Thu, 26 Apr 2012 08:53:19 UTC
      # Architectures: amd64
      # Components: main
      # Description: a debian squeeze based repository for XING software
      # MD5Sum:
      #  ed1acf7aa9b4fd8b7dcb162ea4cdd3b3 641 main/binary-amd64/Packages
      #  36e60311dbde072420def60f72de5014 454 main/binary-amd64/Packages.gz
      #  69edb4bda0aefb099444b203c4386626 170 main/binary-amd64/Release
      # SHA1:
      #  c241b3899b18e70f5d4a5d6a5a34e87430d11753 641 main/binary-amd64/Packages
      #  0d72e911a40cd096a4c727a7a7e9815bbcd4e239 454 main/binary-amd64/Packages.gz
      #  ab4c100c3da0c5e85a9d6ae66caaa995f2e2ca1b 170 main/binary-amd64/Release
      # SHA256:
      #  32b3cc0540f851b357c21dba63c54613405f1cf007386c2a8b26228be4e1da83 641 main/binary-amd64/Packages
      #  c371784d84220d3a1b16795c6ea0f5d8829c1ba1cd12317c80d61ac5484da349 454 main/binary-amd64/Packages.gz
      #  d9ffe826368e151f44cba175c4c155e8edfaa4afe0eda0c2fab93b746dba16d5 170 main/binary-amd64/Release

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
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end
        end
      end
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

