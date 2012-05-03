require_relative 'configuration'

module RepoMate
  class Category

    def initialize(category)
      @config   = Configuration.new
      @category = category
    end

    def name
      @category
    end

    def directory
      File.join(@config.get[:rootdir], @category)
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

    def present
      present = []
      Dir.glob("#{directory}/*").each do |dir|
        present << File.split(dir)[1]
      end
      present
    end

    def self.allstructured
      config  = Configuration.new
      parts = []
      self.all.each do |entry|
        unless entry.nil?
          parts << {
            :category     => entry,
            :basepath     => entry,
            :path         => File.join(config.get[:rootdir], entry)
          }
        end
      end
      parts
    end

    def self.all
      config = Configuration.new
      dirs   = Dir.glob(File.join(config.get[:rootdir], "*"))
      dirs.map{ |dir| File.basename(dir) }
    end

  end
end
