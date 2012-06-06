require 'repomate'
require 'date'
require 'time'

# RepoMate module
module RepoMate

  # Class containing the main logic
  class Base

    # Init
    def initialize
      FileUtils.mkdir_p(Cfg.rootdir)

      @repository = Repository.new
      @link       = Link.new
      @checkpoint = Checkpoint.new
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
      check_versions(workload)
    end

    # Does the link job after checking versions through dpkg
    def check_versions(workload)
      link_workload   = []
      unlink_workload = []

      dpkg = Cfg.dpkg

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
      @link.destroy(unlink_workload)
      @link.create(link_workload)
    end

    # Returns a list of packages
    def list_packages(category)
      packages = []
      number   = 0
      if category.eql?("stage")
        Component.dataset(category).each do |entry|
          source = Component.new(entry[:component], entry[:suitename], category)
          source.files.each do |fullname|
            package = Package.new(fullname, entry[:suitename], entry[:component])

            number += 1

            packages << {
              :number      => number,
              :fullname    => fullname,
              :basename    => File.basename(fullname),
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

            number += 1

            packages << {
              :number       => number,
              :fullname     => fullname,
              :basename     => File.basename(fullname),
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

    # Removes a package
    def remove(package)
      unlink_workload = []

      path = Dir.glob(File.join(Cfg.rootdir, "dists", package[:suitename], package[:component], "*", package[:basename]))

      Dir.glob(path).each do |fullname|
        unlink_workload << { :destination_fullname => fullname }
      end

      @checkpoint.delete_package(package)
      @link.destroy(unlink_workload)
    end
  end
end

