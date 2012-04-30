require_relative 'configuration'
require_relative 'component'
require_relative 'suite'

module RepoMate
  class Pool

    attr_reader :category

    def initialize
      @config   = Configuration.new
      @category = ["stage", "pool", "production"]
    end

    def setup(suitename, component)
      unless Suite.allowed.include?(suitename)
        $stderr.puts "Suitename is not configured"
        exit 1
      end
      unless Component.allowed.include?(component)
        $stderr.puts "Component is not configured"
        exit 1
      end

      @category.each do |name|
        directory = File.join(@config.get[:rootdir], name, suitename, component)

        unless Dir.exists?(directory)
          FileUtils.mkdir_p(directory)
        end
      end
    end

    def pool_dir(suitename, component)
      File.join(@config.get[:rootdir], "pool", suitename, component)
    end

    def stage_dir(suitename, component)
      File.join(@config.get[:rootdir], "stage", suitename, component)
    end

    def production_dir(suitename, component)
      File.join(@config.get[:rootdir], "production", suitename, component)
    end

    def structure
      structures = {}
      Dir.glob(File.join(@config.get[:rootdir], "stage", "*")).each do |suitedir|
        components = []
        suite = File.split(suitedir)

        Dir.glob(File.join(@config.get[:rootdir], "stage", suite[1], "*")).each do |componentdir|
          component = File.split(componentdir)
          components << component[1] unless components.include?(component[1])
        end
        structures[suite[1]] = components unless structures.has_key?(suite[1])
      end
      structures
    end
  end
end

