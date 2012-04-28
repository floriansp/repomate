require_relative '../configuration'

module RepoMate
  class Suite

    def initialize(suitename, stage)
      @config     = Configuration.new
      @suitename  = suitename
      @stage      = stage
    end

    def directory
      File.join(@config.get[:rootdir], @stage, @suitename)
    end

    def exist?
      Dir.exist?(directory)
    end

    def is_allowed?
      @config.get[:components].include?(@suitename)
    end

    def create
      FileUtils.mkdir_p(directory) unless exist?
    end

    def destroy
      FileUtils.rm_r(directory) if exist?
    end

  end
end
