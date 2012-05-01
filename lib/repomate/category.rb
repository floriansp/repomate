require_relative 'configuration'

module RepoMate
  class Category

    def initialize(category)
      @config   = Configuration.new
      @category = category
    end

    def name
      @category
    end

    def directory
      File.join(@config.get[:rootdir], @category)
    end

    def exist?
      Dir.exist?(directory)
    end

    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    def self.all
      config = Configuration.new
      dirs   = Dir.glob(File.join(config.get[:rootdir], "*"))
      dirs.map{ |dir| File.basename(dir) }
    end

  end
end
