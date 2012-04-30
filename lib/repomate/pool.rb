require_relative 'configuration'
require_relative 'component'
require_relative 'suite'

module RepoMate
  class Pool

    attr_reader :category

    def initialize
      @config     = Configuration.new
      @categories = ["stage", "pool", "dists"]
    end

    def setup(suitename, component, architecture)
      unless Suite.allowed.include?(suitename)
        $stderr.puts "Suitename is not configured"
        exit 1
      end
      unless Component.allowed.include?(component)
        $stderr.puts "Component is not configured"
        exit 1
      end

      @categories.each do |category|
        directory = File.join(@config.get[:rootdir], category, suitename, component, "binary-#{architecture}")

        unless Dir.exists?(directory)
          FileUtils.mkdir_p(directory)
        end
      end
    end

    def get_directory(category, suitename, component, architecture)
      File.join(@config.get[:rootdir], category, suitename, component, "binary-#{architecture}")
    end

    def structure(category)
      structures   = []

      Dir.glob(File.join(@config.get[:rootdir], category, "*")).each do |suitedir|
        suitename = File.split(suitedir)
        Dir.glob(File.join(@config.get[:rootdir], category, suitename[1], "*")).each do |componentdir|
          component = File.split(componentdir)
          Dir.glob(File.join(@config.get[:rootdir], category, suitename[1], component[1], "*")).each do |architecturedir|
            architecture_dir = File.split(architecturedir)
            architecture = architecture_dir[1].split("-")
            structures << { :suitename => suitename[1], :component => component[1], :architecture_dir => architecture_dir[1], :architecture => architecture[1]}
          end
        end
      end
      structures
    end
  end
end

