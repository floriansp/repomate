require_relative 'configuration'

# RepoMate module
module RepoMate

  # Class for the category layer of the directory structure
  class Category

    # Init
    def initialize(category)
      @config   = Configuration.new
      @category = category
    end

    # Returns the name of the category (eg. pool, dists)
    def name
      @category
    end

    # Returns the full path of the categories directory
    def directory
      File.join(@config.get[:rootdir], @category)
    end

    # Checks if the category directory exists
    def exist?
      Dir.exist?(directory)
    end

    # Creates the directory strcuture of the category
    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    # Deletes a categories directory
    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    # Returns all directory basenames of all present categories as array (eg. ["pool", "dists])
    def self.dirnames
      names = []
      self.all.each do |dir|
        names << File.split(dir).last unless names.include? File.split(dir).last
      end
      names
    end

    # Returns all present category names as array (["pool", "dists])
    def self.names
      self.dirnames
    end

    # Returns a dataset including the name of the category, the basepath and the fullpath
    def self.dataset(category=nil)
      config = Configuration.new
      data   = []
      self.all.each do |entry|
        unless entry.nil?
          next unless entry.eql?(category) || category.eql?("all")
          data << {
            :category     => entry,
            :basepath     => entry,
            :fullpath     => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

    # Returns all directories
    def self.all
      config = Configuration.new
      dirs   = Dir.glob(File.join(config.get[:rootdir], "*"))
      dirs.map{ |dir| File.basename(dir) }
    end

  end
end
