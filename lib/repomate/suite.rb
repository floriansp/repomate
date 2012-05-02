require_relative 'configuration'
require_relative 'category'

module RepoMate
  class Suite

    def initialize(suitename, category)
      @config     = Configuration.new
      @suitename  = suitename
      @category   = category
    end

    def name
      @suitename
    end

    def directory
      File.join(@config.get[:rootdir], @category, @suitename)
    end

    def exist?
      Dir.exist?(directory)
    end

    def is_allowed?
      self.allowed.include?(@suitename)
    end

    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    def present
      present = []
      Dir.glob("#{directory}/*").each do |dir|
        present << File.split(dir)[1]
      end
      present
    end

    def packagesfiles
      Dir.glob("#{directory}/Packages*")
    end

    def releasefiles
      Dir.glob("#{directory}/Release*")
    end

    def self.all
      config      = Configuration.new
      categories  = Category.all
      dirs        = []
      rootdir     = config.get[:rootdir]
      categories.each do |category|
        suites = Dir.glob(File.join(rootdir, category, "*"))
        suites.each do |suite|
          dirs.push suite.gsub(/#{rootdir}\//, '')
        end
      end
      return dirs
    end

    def self.allowed
      Configuration.new.get[:suites].uniq
    end

  end
end

