# RepoMate module
module RepoMate

  # Class for the category layer of the directory structure
  class Category

    # Init
    def initialize(category)
      @category = category
    end

    # Returns the name of the category (eg. pool, dists)
    def name
      @category
    end

    # Returns the full path of the categories directory
    def directory
      File.join(Cfg.rootdir, @category)
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

    # Returns a dataset including the name of the category and the fullpath
    def self.dataset(category=nil)
      data   = []
      self.all.each do |entry|
        unless entry.nil?
          next unless entry.eql?(category) || category.eql?("all")
          data << {
            :category     => entry,
            :fullpath     => File.join(Cfg.rootdir, entry)
          }
        end
      end
      data
    end

    # Returns all directories
    def self.all
      dirs   = Dir.glob(File.join(Cfg.rootdir, "*"))
      dirs.map{ |dir| File.basename(dir) unless dirs.include?(File.basename(dir)) }
    end

  end
end

