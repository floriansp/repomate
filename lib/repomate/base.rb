require 'date'
require 'time'
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'
require_relative 'configuration'
require_relative 'package'
require_relative 'pool'

module RepoMate
  class Base

    def initialize
      @config = Configuration.new
    end

    ### Main methods
    def stage(workload)
      workload.each do |entry|
        package = Package.new(entry[:package_fullname], entry[:suitename])
        source  = entry[:package_fullname]
        dest    = File.join(pool.stage_dir(entry[:suitename], entry[:component]), package.newbasename)

        pool.setup(entry[:suitename], entry[:component])

        FileUtils.copy(source, dest)
      end
    end

    def prepare_publish
      workload = []
      pool.structure.each do |suitename, components|
        components.each do |component|
          debfiles = File.join(pool.stage_dir(suitename, component), "*.deb")

          Dir.glob(debfiles) do |source_fullname|
            package              = Package.new(source_fullname, suitename)
            destination_fullname = File.join(pool.pool_dir(suitename, component), package.newbasename)
            workload << {
              :source_fullname      => source_fullname,
              :destination_fullname => destination_fullname,
              :component            => component,
              :suitename            => suitename
            }
          end
        end
      end
      workload
    end

    def publish(workload)
      newworkload = []
      workload.each do |entry|
        newworkload << {
          :source_fullname => entry[:destination_fullname],
          :destination_dir => pool.production_dir(entry[:suitename], entry[:component]),
          :component       => entry[:component],
          :suitename       => entry[:suitename]
        }
        FileUtils.move(entry[:source_fullname], entry[:destination_fullname])
      end
      workload = newworkload

      save_checkpoint
      link(workload)
    end

    def link(workload)
      dpkg   = @config.get[:dpkg]

      raise "dpkg is not installed" unless File.exists?(dpkg)

      link   = []
      unlink = []
      action = false

      workload.each do |entry|
        source_package  = Package.new(entry[:source_fullname], entry[:suitename])
        source_version  = source_package.controlfile['Version']
        debfiles        = "#{entry[:destination_dir]}/#{source_package.controlfile['Package']}*.deb"
        destination_fullname = File.join(entry[:destination_dir], source_package.newbasename)

        Dir.glob(debfiles) do |target_fullname|
          target_package = Package.new(destination_fullname, entry[:suitename])
          target_version = target_package.controlfile['Version']

          if system("#{dpkg} --compare-versions #{source_version} gt #{target_version}")
            puts "Package: #{target_package.newbasename} replaced with #{source_package.newbasename}"
            unlink << {
              :destination_fullname => target_fullname,
              :basename => target_package.newbasename
            }
          elsif system("#{dpkg} --compare-versions #{source_version} eq #{target_version}")
          puts "Package: #{source_package.newbasename} already exists with same version"
          elsif system("#{dpkg} --compare-versions #{source_version} lt #{target_version}")
          puts "Package: #{source_package.newbasename} already exists with higher version"
          end
        end

        link << {
          :source_fullname      => entry[:source_fullname],
          :destination_fullname => destination_fullname,
          :suitename            => entry[:suitename],
          :component            => entry[:component],
          :basename             => source_package.newbasename
        }
      end

      unlink.each do |entry|
        File.unlink(entry[:destination_fullname])
        puts "Package: #{entry[:basename]} unlinked"
        action = true
      end

      link.each do |entry|
        File.symlink(entry[:source_fullname], entry[:destination_fullname]) unless File.exists?(entry[:destination_fullname])
        puts "Package: #{entry[:basename]} linked to production => #{entry[:suitename]}/#{entry[:component]}"
        action = true
      end

      if action
        scan_packages
      end
    end

    def scan_packages
      pool.structure.each do |suitename, components|
        components.each do |component|
          packages    = File.join(pool.production_dir(suitename, component), "Packages")
          packages_gz = File.join(pool.production_dir(suitename, component), "Packages.gz")
          debfiles    = File.join(pool.production_dir(suitename, component), "*.deb")

          File.unlink(packages) if File.exists?(packages)

          Dir.glob(debfiles) do |fullname|
            package = Package.new(fullname, suitename)

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
      end
    end

    def save_checkpoint
      datetime = DateTime.now
      File.open(@config.get[:redolog], 'a') do |file|
      pool.structure.each do |suitename, components|
        components.each do |component|
            debfiles = File.join(pool.production_dir(suitename, component), "*.deb")
            Dir.glob(debfiles) do |fullname|
              basename = File.basename(fullname)
              file.puts "#{datetime} #{suitename} #{component} #{basename}"
              puts "Package: #{basename} #{suitename}/#{component} added to log"
            end
          end
        end
      end
      puts "Checkpoint (#{datetime.strftime("%F %T")}) saved"
    end

    def load_checkpoint(number)
      list     = get_checkpoints
      workload = []

      pool.structure.each do |suitename, components|
        components.each do |component|
          debfiles = File.join(pool.production_dir(suitename, component), "*.deb")
          Dir.glob(debfiles) do |fullname|
            File.unlink fullname
          end
        end
      end

      File.open(@config.get[:redolog], 'r') do |file|
        while (line = file.gets)
          if line.split[0] == list[number]
            suitename    = line.split[1]
            component    = line.split[2]
            basename     = line.split[3]

            workload << {
              :source_fullname => File.join(pool.pool_dir(suitename, component), basename),
              :destination_dir => pool.production_dir(suitename, component),
              :component       => component,
              :suitename       => suitename
            }
          end
        end
      end

      link(workload)
    end

    def get_checkpoints
      unless File.exists?(@config.get[:redolog])
        puts "We can't restore because we don't have checkpoints"
        exit 1
      end

      order = 0
      dates = []
      list  = {}

      File.open(@config.get[:redolog], 'r') do |file|
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
      pool.structure.each do |suitename, components|
        components.each do |component|
          debfiles = File.join(@config.get[:rootdir], category, suitename, component, "*.deb")
          Dir.glob(debfiles) do |fullname|
            package = Package.new(fullname, suitename)

            packages << {
              :fullname    => fullname,
              :controlfile => package.controlfile,
              :component   => component,
              :suitename   => suitename,
            }
          end
        end
      end
      packages
    end

    protected

    def pool
      @pool ||= Pool.new
    end
  end
end

