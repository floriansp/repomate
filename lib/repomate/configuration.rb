require 'yaml'

module RepoMate
  class Configuration

    attr_reader :get

    def initialize
      @configfiles = [File.join(ENV['HOME'], '.repomate'), File.join(File.dirname(__FILE__), '..', '..', 'etc', 'config.yml')]
    end

    def get
      @configfiles.each do |file|
        if File.exist?(file)
          return YAML::load_file(file)
        end
      end
    end

  end
end

