require_relative 'configuration'

class Pool
  def initialize
    @config   = Configuration.new
    @category = ["stage", "archive", "pool"]
  end

  def setup(distname)
    if not allowed_distributions.include?(distname)
      puts "Distname is not configured"
      exit 0
    end

    @category.each do |name|
      directory = File.join(@config.get[:rootdir], name, distname)

      unless Dir.exists?(directory)
        FileUtils.mkdir_p(directory)
      end
    end
  end

  def archive_dir(distname)
    File.join(@config.get[:rootdir], "archive", distname)
  end

  def stage_dir(distname)
    File.join(@config.get[:rootdir], "stage", distname)
  end

  def pool_dir(distname)
    File.join(@config.get[:rootdir], "pool", distname)
  end

  def allowed_distributions
    distributions = []
    @config.get[:distributions].each do |name|
      distributions << name unless distributions.include?(name)
    end
    distributions
  end

  def active_distributions
    distributiondir = Dir.glob(File.join(@config.get[:rootdir], "*", "*"))
    distributions   = []

    distributiondir.each do |name|
      basename = File.basename(name)
      distributions << basename unless distributions.include?(basename)
    end
    distributions
  end
end

