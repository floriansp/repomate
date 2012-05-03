require_relative 'configuration'
require_relative 'category'
require_relative 'suite'

module RepoMate
  class Component

    def initialize(component, suitename, category)
      @config     = Configuration.new
      @component  = component
      @suitename  = suitename
      @category   = category
    end

    def name
      @component
    end

    def directory
      File.join(@config.get[:rootdir], @category, @suitename, @component)
    end

    def exist?
      Dir.exist?(directory)
    end

    def is_allowed?
      self.allowed.include?(@component)
    end

    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    def files
      Dir.glob("#{directory}/*.deb")
    end

    def self.allabove(category=nil)
      config = Configuration.new
      data  = []
      self.all.each do |entry|
        parts = entry.split(/\//)
        unless parts[0].nil? || parts[1].nil? || parts[2].nil?
          next unless parts[0].eql?(category) || category.eql?("all")
          data << {
            :category     => parts[0],
            :suitename    => parts[1],
            :component    => parts[2],
            :basepath     => entry,
            :path         => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

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

    def self.allowed
      Configuration.new.get[:components].uniq
    end

  end
end

