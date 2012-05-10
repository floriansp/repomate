# require 'repomate/configuration'
# require 'repomate/category'
# require 'repomate/suite'

# RepoMate module
module RepoMate

  # Class for the component layer of the directory structure
  class Component

    # Init
    def initialize(component, suitename, category)
      @config     = Configuration.new
      @component  = component
      @suitename  = suitename
      @category   = category
    end

    # Returns the given architecture name (eg. main, contrib, non-free)
    def name
      @component
    end

    # Returns the directory strcuture of the component including all lower layers
    def directory
      File.join(@config.get[:rootdir], @category, @suitename, @component)
    end

    # Checks if the component directory exists
    def exist?
      Dir.exist?(directory)
    end

    # Checks if the component is allowed (See: configurationfile)
    def is_allowed?
      self.allowed.include?(@component)
    end

    # Checks if directory is unused
    def is_unused?(dir)
      status  = true

      path = Dir.glob(File.join(dir, "*"))
      path.each do |dirorfile|
        status = false if File.directory?(dirorfile)
        status = false if File.basename(dirorfile) =~ /\.deb$/
      end

      status
    end

    # Creates the directory strcuture of the component including all lower layers
    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    # Deletes the components directory including all lower layers
    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    # Returns a list of all debian files in the component directory
    def files
      Dir.glob(File.join(directory, "*.deb"))
    end

    # Returns a dataset including the name of the component, the fullpath recursive through all lower layers
    def self.dataset(category=nil)
      config = Configuration.new
      data  = []
      self.all.each do |entry|
        parts = entry.split(/\//)
        unless parts.length < 3
          next unless parts[0].eql?(category) || category.eql?("all")
          data << {
            :category     => parts[0],
            :suitename    => parts[1],
            :component    => parts[2],
            :fullpath     => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

    # Returns all directories without @rootdir
    def self.all
      config  = Configuration.new
      suites  = Suite.all
      dirs    = []
      rootdir = config.get[:rootdir]
      suites.each do |suite|
        components = Dir.glob(File.join(rootdir, suite, "*"))
        components.each do |component|
          dirs.push component.gsub(/#{rootdir}\//, '') if File.directory? component
        end
      end
      return dirs
    end

    # Gets all configured architectures
    def self.allowed
      Configuration.new.get[:components].uniq
    end

  end
end

