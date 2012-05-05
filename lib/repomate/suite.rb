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

    def self.names
      names = []
      self.all.each do |dir|
        names << File.split(dir).last unless names.include? File.split(dir).last
      end
      names
    end

    def self.allabove(category=nil)
      config = Configuration.new
      data   = []
      self.all.each do |entry|
        parts = entry.split(/\//)
        unless parts.length < 2
          next unless parts[0].eql?(category) || category.eql?("all")
          data << {
            :category     => parts[0],
            :suitename    => parts[1],
            :basepath     => entry,
            :fullpath         => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

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

    def self.allowed
      Configuration.new.get[:suites].uniq
    end

  end
end

