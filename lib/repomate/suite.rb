require_relative 'configuration'
require_relative 'category'

# RepoMate module
module RepoMate

  # Class for the suite layer of the directory structure
  class Suite

    # Init
    def initialize(suitename, category)
      @config     = Configuration.new
      @suitename  = suitename
      @category   = category
    end

    # Returns the given suite name (eg. lenny, squeeze)
    def name
      @suitename
    end

    # Returns the directory strcuture of the suite including all lower layers
    def directory
      File.join(@config.get[:rootdir], @category, @suitename)
    end

    # Checks if the suite directory exists
    def exist?
      Dir.exist?(directory)
    end

    # Checks if the suite is allowed (See: configurationfile)
    def is_allowed?
      self.allowed.include?(@suitename)
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

    # Creates the directory strcuture of the suite including all lower layers
    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    # Deletes the suites directory including all lower layers
    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    # Returns a dataset including the name of the suite, the fullpath recursive through all lower layers
    def self.dataset(category=nil)
      config = Configuration.new
      data   = []
      self.all.each do |entry|
        # p entry
        parts = entry.split(/\//)
        unless parts.length < 2
          next unless parts[0].eql?(category) || category.eql?("all")

          data << {
            :category     => parts[0],
            :suitename    => parts[1],
            :fullpath     => File.join(config.get[:rootdir], entry),
          }
        end
      end
      data
    end

    # Returns all directories without @rootdir
    def self.all
      config      = Configuration.new
      categories  = Category.all
      dirs        = []
      rootdir     = config.get[:rootdir]
      categories.each do |category|
        suites = Dir.glob(File.join(rootdir, category, "*"))
        suites.each do |suite|
          dirs.push suite.gsub(/#{rootdir}\//, '') if File.directory? suite
        end
      end
      return dirs
    end

    # Gets all configured architectures
    def self.allowed
      Configuration.new.get[:suites].uniq
    end

  end
end

