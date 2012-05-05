require 'yaml'

# RepoMate module
module RepoMate

  # Configuration class
  class Configuration

    attr_reader :get

    # Init
    def initialize
      @configfiles = [File.join(ENV['HOME'], '.repomate'), File.join(File.dirname(__FILE__), '..', '..', 'etc', 'config.yml')]
    end

    # Returns configured values as hash, keys are symbols
    def get
      @configfiles.each do |file|
        if File.exist?(file)
          return YAML::load_file(file)
        end
      end
    end

  end
end

