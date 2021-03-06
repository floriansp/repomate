require 'repomate'
require 'date'
require 'time'

# RepoMate module
module RepoMate

  # Class containing the main logic
  class Base

    # Init
    def initialize
      FileUtils.mkdir_p(Cfg.rootdir) unless File.exists?(Cfg.rootdir)

      @repository = Repository.new
      @link       = Link.new
      @checkpoint = Checkpoint.new
      @metafile   = Metafile.new
    end

    # Add's a package to the staging area
    def stage(workload)
      workload.each do |entry|
        @repository.create(entry[:suitename], entry[:component])

        package     = Package.new(entry[:package_fullname], entry[:suitename], entry[:component])
        destination = Component.new(entry[:component], entry[:suitename], "stage")

        FileUtils.move(entry[:package_fullname], File.join(destination.directory, package.newbasename))
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
      link_workload   = []
      unlink_workload = []

      workload.each do |entry|

        action = true

        @repository.create(entry[:suitename], entry[:component], entry[:architecture])

        package        = Package.new(entry[:source_fullname], entry[:suitename], entry[:component])
        pool           = Architecture.new(package.architecture, entry[:component], entry[:suitename], "pool")
        dists          = Architecture.new(package.architecture, entry[:component], entry[:suitename], "dists")
        pool_fullname  = File.join(pool.directory, package.basename)
        dists_fullname = File.join(dists.directory, package.basename)
        stage_fullname = package.fullname

        Dir.glob("#{pool.directory}/#{package.name}*.deb") do |pool_fullname|
          pool_package = Package.new(pool_fullname, entry[:suitename], entry[:component] )
          if system("#{Cfg.dpkg} --compare-versions #{package.version} gt #{pool_package.version}")
            puts "Package: #{pool_package.newbasename} will be replaced with #{package.newbasename}"
          elsif system("#{Cfg.dpkg} --compare-versions #{package.version} eq #{pool_package.version}")
            puts "Package: #{pool_package.newbasename} already exists with same version"
            action = false
            next
          elsif system("#{Cfg.dpkg} --compare-versions #{package.version} lt #{pool_package.version}")
            puts "Package: #{pool_package.newbasename} already exists with higher version"
            File.unlink(package.fullname)
            action = false
            next
          end
        end

        if action
          link_workload << {
            :source_fullname      => pool_fullname,
            :destination_fullname => dists_fullname,
            :suitename            => package.suitename,
            :component            => package.component,
            :architecture         => package.architecture
          }
                    
          Dir.glob("#{dists.directory}/#{package.name}*.deb") do |fullname|
            unlink_workload << {
              :destination_fullname => fullname,
              :suitename            => package.suitename,
              :component            => package.component,
              :category             => 'dists'
            }
          end
          
          FileUtils.move(stage_fullname, pool_fullname) unless File.exists?(pool_fullname)
        end
      end
      
      @link.destroy(unlink_workload) unless unlink_workload.empty?
      @link.create(link_workload) unless link_workload.empty?
      @metafile.create unless link_workload.empty?
    end

    # Returns a list of packages
    def listpackages
      packages = []

      @repository.categories.each do |category|
        Architecture.dataset(category).each do |entry|
          source = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], category)
          source.files.each do |fullname|
            package = Package.new(fullname, entry[:suitename], entry[:component])
            packages << {
              :fullname    => fullname,
              :category    => category,
              :basename    => File.basename(fullname),
              :controlfile => package.controlfile,
              :component   => entry[:component],
              :suitename   => entry[:suitename],
              :architecture => entry[:architecture]
            }
          end
        end
        if category.eql? "stage"
          Component.dataset(category).each do |entry|
            source = Component.new(entry[:component], entry[:suitename], category)
            source.files.each do |fullname|
              package = Package.new(fullname, entry[:suitename], entry[:component])
              packages << {
                :fullname    => fullname,
                :category    => category,
                :basename    => File.basename(fullname),
                :controlfile => package.controlfile,
                :component   => entry[:component],
                :suitename   => entry[:suitename],
                :architecture => "unknown"
              }
            end
          end
        end
      end
      packages
    end

    # Activates a package
    def activate(entry)
      link_workload = []

      package        = Package.new(entry[:fullname], entry[:suitename], entry[:component])
      dists          = Architecture.new(package.architecture, entry[:component], entry[:suitename], "dists")
      dists_fullname = File.join(dists.directory, package.basename)

      link_workload << {
        :source_fullname      => entry[:fullname],
        :destination_fullname => dists_fullname,
        :suitename            => package.suitename,
        :component            => package.component,
        :architecture         => package.architecture
      }
      if File.exists?(dists_fullname)
        puts "Package already activated"
      else
        @link.create(link_workload)
        @metafile.create
      end
    end

    # Deactivates a package
    def deactivate(entry, mode)
      unlink_workload = []

      @repository.categories.each do |category|
        next if mode.eql?("deactivate") && category.eql?("pool")

        path = Dir.glob(File.join(Cfg.rootdir, category, entry[:suitename], entry[:component], "*", entry[:basename]))

        Dir.glob(path).each do |fullname|
          unlink_workload << {
            :destination_fullname => fullname,
            :category             => category,
            :suitename            => entry[:suitename],
            :component            => entry[:component]
          }
        end
      end

      @checkpoint.delete_package(entry) if mode.eql?("remove")
      @link.destroy(unlink_workload)
      @metafile.create
    end
  end
end

