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

    def present
      present = []
      Dir.glob("#{directory}/*").each do |dir|
        present << File.split(dir)[1]
      end
      present
    end

    def self.allstructured
      config  = Configuration.new
      parts = []
      self.all.each do |entry|
        s = entry.split(/\//)
        unless s[0].nil? || s[1].nil? || s[2].nil?
          parts << {
            :category     => s[0],
            :suitename    => s[1],
            :component    => s[2],
            :basepath     => entry,
            :path         => File.join(config.get[:rootdir], entry)
          }
        end
      end
      parts
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

