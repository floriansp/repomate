require 'yaml'

module RepoMate
  class Configuration
    attr_reader :get

    def initialize
      @configfile = File.dirname(File.expand_path(__FILE__)) + '/../../etc/config.yml'
    end

    def get
      YAML::load_file(@configfile)
    end
  end
end
