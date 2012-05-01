require_relative 'configuration'
require_relative 'component'
require_relative 'category'
require_relative 'suite'

module RepoMate
  class Architecture

    def initialize(architecture, component, suitename, category)
      @config       = Configuration.new
      @architecture = architecture
      @component    = component
      @suitename    = suitename
      @category     = category
    end

    def name
      @architecture
    end

    def directory
      File.join(@config.get[:rootdir], @category, @suitename, @component, "binary-#{name}")
    end

    def exist?
      Dir.exist?(directory)
    end

    def is_allowed?
      self.allowed.include?(@architecture)
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

    def self.all
      config      = Configuration.new
      components  = Component.all
      dirs        = []
      rootdir     = config.get[:rootdir]
      components.each do |component|
        p component
        architectures = Dir.glob(File.join(rootdir, component, "*"))
        architectures.each do |architecture|
          dirs.push architecture.gsub(/#{rootdir}\//, '')
        end
      end
      return dirs
    end

    def self.allowed
      Configuration.new.get[:architectures].uniq
    end

  end
end

