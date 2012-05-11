require 'yaml'

# RepoMate module
module RepoMate

  # Configuration class
  class Configuration

    # Init
    def initialize
      @configfile = File.join(ENV['HOME'], '.repomate')

      configure(@configfile)
    end

    # Loads configfile
    def configure(configfile)
      filecontent = []

      filecontent = YAML::load_file(configfile) if File.exists?(configfile)

      merge(filecontent)
    end

    # Merges configfile content with defaults
    def merge(filecontent=nil)
      config = {}

      defaults = {
        :rootdir       => '/var/lib/repomate/repository',
        :logdir        => '/var/log/repomate',
        :redolog       => 'redo.log',
        :database      => 'repomate.db',
        :dpkg          => '/usr/bin/dpkg',
        :suites        => [ "lenny", "squeeze" ],
        :components    => [ "main", "contrib" ],
        :architectures => [ "all", "amd64" ],
        :origin        => 'Repository',
        :label         => 'Repository',
        :gpg_enable    => 'yes',
        :gpg_email     => 'someone@example.net',
        :gpg_password  => 'secret',
      }

      if filecontent
        defaults.each do |key, value|
          keysymbol = key.to_sym
          setter = "#{key}="

          if filecontent[keysymbol]
            config[keysymbol] = filecontent[keysymbol]
          else
            config[keysymbol] = value
          end
        end
      else
        config = defaults
      end

      config.each do |key, value|
        setter = "#{key}="

        self.class.send(:attr_accessor, key) unless respond_to?(setter)

        send setter, value
      end
    end
  end

  # Returns
  Cfg = Configuration.new

end




