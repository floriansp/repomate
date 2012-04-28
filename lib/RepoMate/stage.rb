require_relative '../configuration'

module RepoMate
  class Stage

    def initialize(stage)
      @config     = Configuration.new
      @stage      = stage
    end

    def directory
      File.join(@config.get[:rootdir], @stage)
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

  end
end
