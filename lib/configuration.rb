require 'yaml'

class Configuration
  attr_reader :get

  def initialize
    @configfile = File.realpath("../etc/config.yml")
  end

  def get
    YAML::load_file(@configfile)
  end
end
