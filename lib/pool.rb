require_relative 'configuration'

class Pool
  def initialize
    @config   = Configuration.new
    @category = ["stage", "archive", "production"]
  end

  def setup(distname)
    if not alloweddistributions.include?(distname)
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

  def archivedir(distname)
    File.join(@config.get[:rootdir], "archive", distname)
  end

  def stagedir(distname)
    File.join(@config.get[:rootdir], "stage", distname)
  end

  def productiondir(distname)
    File.join(@config.get[:rootdir], "production", distname)
  end

  def alloweddistributions
    distributions = Array.new
    @config.get[:distributions].each do |name|
      distributions.push(name) unless distributions.include?(name)
    end
    distributions
  end

  def activedistributions
    distributiondir = Dir.glob(File.join(@config.get[:rootdir], "*", "*"))
    distributions   = Array.new

    distributiondir.each do |name|
      basename = File.basename(name)
      distributions.push(basename) unless distributions.include?(basename)
    end
    distributions
  end
end

# push -> <<
# config initialize
# array-new -> []
