require_relative 'configuration'

class Pool
  def initialize
    @config   = Configuration.new
    @category = ["stage", "pool", "production"]
  end

  def setup(suitename, component)
    # if not allowed_suites.include?(suitename)
    #   puts "suitename is not configured"
    #   exit 0
    # end

    @category.each do |name|
      directory = File.join(@config.get[:rootdir], name, suitename, component)

      unless Dir.exists?(directory)
        FileUtils.mkdir_p(directory)
      end
    end
  end

  def pool_dir(suitename, component)
    File.join(@config.get[:rootdir], "pool", suitename, component)
  end

  def stage_dir(suitename, component)
    File.join(@config.get[:rootdir], "stage", suitename, component)
  end

  def production_dir(suitename, component)
    File.join(@config.get[:rootdir], "production", suitename, component)
  end

  # def allowed_suites
  #   suites = []
  #   @config.get[:suites].each do |name|
  #     suites << name unless suites.include?(name)
  #   end
  #   suites
  # end

  def structure
    structures = {}
    Dir.glob(File.join(@config.get[:rootdir], "stage", "*")).each do |suitedir|
      components = []
      suite = File.split(suitedir)

      Dir.glob(File.join(@config.get[:rootdir], "stage", suite[1], "*")).each do |componentdir|
        component = File.split(componentdir)
        components << component[1] unless components.include?(component[1])
      end
      structures[suite[1]] = components unless structures.has_key?(suite[1])
    end
    structures
  end
end




