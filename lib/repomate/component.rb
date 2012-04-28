require_relative '../configuration'
require_relative 'stage'
require_relative 'suite'

module RepoMate
  class Component

    def initialize(component, suitename, stage)
      @config     = Configuration.new
      @component  = component
      @suitename  = suitename
      @stage      = stage
    end

    def directory
      File.join(@config.get[:rootdir], @stage, @suitename, @component)
    end

    def exist?
      Dir.exist?(directory)
    end

    def is_allowed?
      @config.get[:components].include?(@component)
    end

    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    def destroy
      FileUtils.rm_r(directory) if exist?
    end

    def self.all
      config  = Configuration.new
      suites  = RepoMate::Suite.all
      dirs    = []
      rootdir = config.get[:rootdir]
      suites.each do |suite|
        components = Dir.glob(File.join(rootdir, suite, "*"))
        components.each do |component|
          dirs.push component.gsub(/#{rootdir}\//, '')
        end
      end
      return dirs
    end


  end
end

