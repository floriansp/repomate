class Pool
  def initialize
    @category = ["stage", "archive", "production"]
  end

  def setup(distname)
    if not alloweddistributions.include?(distname)
      puts "Distname is not configured"
      exit 0
    end

    @category.each do |name|
      directory = File.join($config[:rootdir], name, distname)

      unless Dir.exists?(directory)
        FileUtils.mkdir_p(directory)
      end
    end
  end

  def archivedir(distname)
    File.join($config[:rootdir], "archive", distname)
  end

  def stagedir(distname)
    File.join($config[:rootdir], "stage", distname)
  end

  def productiondir(distname)
    File.join($config[:rootdir], "production", distname)
  end

  def alloweddistributions
    distributions = Array.new
    $config[:distributions].each do |name|
      distributions.push(name) unless distributions.include?(name)
    end
    distributions
  end

  def activedistributions
    distributiondir = Dir.glob(File.join($config[:rootdir], "*", "*"))
    distributions   = Array.new

    distributiondir.each do |name|
      basename = File.basename(name)
      distributions.push(basename) unless distributions.include?(basename)
    end
    distributions
  end
end
