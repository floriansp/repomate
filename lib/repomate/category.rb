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

    def self.dirnames
      names = []
      self.all.each do |dir|
        names << File.split(dir).last unless names.include? File.split(dir).last
      end
      names
    end

    def self.names
      self.dirnames
    end

    def self.dataset(category=nil)
      config = Configuration.new
      data   = []
      self.all.each do |entry|
        unless entry.nil?
          next unless entry.eql?(category) || category.eql?("all")
          data << {
            :category     => entry,
            :basepath     => entry,
            :fullpath     => File.join(config.get[:rootdir], entry)
          }
        end
      end
      data
    end

    def self.all
      config = Configuration.new
      dirs   = Dir.glob(File.join(config.get[:rootdir], "*"))
      dirs.map{ |dir| File.basename(dir) }
    end

  end
end
