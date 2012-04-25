class Pool
  def initialize
    @category = ["stage", "archive", "production"]

    setup
  end

  def setup(*distname)
    @category.each do |name|
      directory = nil
      if distname
        directory = File.join($config[:rootdir], name, distname)
      else
        directory = File.join($config[:rootdir], name)
      end
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

  def distributions
    distributiondir = Dir.glob(File.join($config[:rootdir], "*", "*"))
    distributions   = Array.new

    distributiondir.each do |name|
      basename = File.basename(name)
      distributions.push(basename) unless distributions.include?(basename)
    end
    distributions
  end
end
