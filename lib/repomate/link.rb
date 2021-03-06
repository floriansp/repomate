require 'repomate'

# RepoMate module
module RepoMate

  # Class containing the main logic
  class Link

    # Init
    def initialize
      @repository = Repository.new
      @metafile   = Metafile.new
    end

    # Checks if file exists
    def exist?(fullname)
      File.exists?(fullname)
    end

    # links the workload
    def create(workload)
      workload.each do |entry|
        @repository.create(entry[:suitename], entry[:component], entry[:architecture])

        unless File.exists?(entry[:destination_fullname])
          package = Package.new(entry[:source_fullname], entry[:suitename], entry[:component])
          
          package.create_checksums

          File.symlink(entry[:source_fullname], entry[:destination_fullname])
          puts "Package: #{package.newbasename} linked to production => #{entry[:suitename]}/#{entry[:component]}"
        end
      end
    end

    # unlinks workload
    def destroy(workload)
      workload.each do |entry|
        package = Package.new(entry[:destination_fullname], entry[:suitename], entry[:component])
        package.delete_checksums

        if File.exists?(entry[:destination_fullname])
          File.unlink(entry[:destination_fullname])
          puts "Package: #{package.newbasename} unlinked from #{entry[:category]} => #{entry[:suitename]}/#{entry[:component]}"
        else
          puts "Package: #{package.newbasename} was not linked"
        end
      end
      
      cleanup unless workload.empty?
    end

    # cleans up unused directories
    def cleanup
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
      
      @metafile.create if action
    end
  end
end
