require_relative 'configuration'

class Pool
  def initialize
    @config   = Configuration.new
    @category = ["stage", "pool", "production"]
  end

  def setup(suitename)
    if not allowed_suites.include?(suitename)
      puts "suitename is not configured"
      exit 0
    end

    @category.each do |name|
      directory = File.join(@config.get[:rootdir], name, suitename)

      unless Dir.exists?(directory)
        FileUtils.mkdir_p(directory)
      end
    end
  end

  def pool_dir(suitename)
    File.join(@config.get[:rootdir], "pool", suitename)
  end

  def stage_dir(suitename)
    File.join(@config.get[:rootdir], "stage", suitename)
  end

  def production_dir(suitename)
    File.join(@config.get[:rootdir], "production", suitename)
  end

  def allowed_suites
    suites = []
    @config.get[:suites].each do |name|
      suites << name unless suites.include?(name)
    end
    suites
  end

  def active_suites
    suitedir = Dir.glob(File.join(@config.get[:rootdir], "*", "*"))
    suites   = []

    suitedir.each do |name|
      basename = File.basename(name)
      suites << basename unless suites.include?(basename)
    end
    suites
  end
end

