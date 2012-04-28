require_relative '../configuration'

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

  end
end

