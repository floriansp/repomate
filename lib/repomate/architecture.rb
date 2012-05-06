require_relative 'configuration'
require_relative 'component'
require_relative 'category'
require_relative 'suite'

# RepoMate module
module RepoMate

  # Class for the architecture layer of the directory structure
  class Architecture

    # Init
    def initialize(architecture, component, suitename, category)
      @config       = Configuration.new
      @architecture = architecture
      @component    = component
      @suitename    = suitename
      @category     = category
    end

    # Returns the given architecture name (eg. all, amd64)
    def name
      @architecture
    end

    # Returns the directory strcuture of the architecture including all lower layers
    def directory
      File.join(@config.get[:rootdir], @category, @suitename, @component, "binary-#{name}")
    end

    # Checks if the architecture directory exists
    def exist?
      Dir.exist?(directory)
    end

    # Checks if the architecture is allowed (See: configurationfile)
    def is_allowed?
      self.allowed.include?(@architecture)
    end

    # Creates the directory strcuture of the architecture including all lower layers
    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    # Deletes the architecture directory including all lower layers
    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    # Returns a list of all debian files in the architecture directory
    def files
      Dir.glob(File.join(directory, "*.deb"))
    end

    # Returns a dataset including the name of the architecture, the basepath and the fullpath recursive through all lower layers
    def self.dataset(category=nil)
      config = Configuration.new
      data   = []
      self.all.each do |entry|
        parts = entry.split(/\//)
        unless parts.length < 4
          next unless parts[0].eql?(category) || category.eql?("all")
          architecture = parts[3].split(/-/)
          data << {
            :category         => parts[0],
            :suitename        => parts[1],
            :component        => parts[2],
            :architecture_dir => parts[3],
            :architecture     => architecture[1],
            :basepath         => entry,
            :fullpath         => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

    # Returns all directories without @rooddir
    def self.all
      config      = Configuration.new
      components  = Component.all
      dirs        = []
      rootdir     = config.get[:rootdir]
      components.each do |component|
        architectures = Dir.glob(File.join(rootdir, component, "*"))
        architectures.each do |architecture|
          dirs.push architecture.gsub(/#{rootdir}\//, '') if File.directory? architecture
        end
      end
      return dirs
    end

    # Gets all configured architectures
    def self.allowed
      Configuration.new.get[:architectures].uniq
    end

  end
end

