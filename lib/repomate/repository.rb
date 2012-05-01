require_relative 'configuration'
require_relative 'architecture'
require_relative 'component'
require_relative 'category'
require_relative 'suite'

module RepoMate
  class Repository

    def initialize
      @config     = Configuration.new
      @categories = ["stage", "pool", "dists"]
    end

    def create(suitename=nil, component=nil, architecture=nil)
      unless Suite.allowed.include?(suitename)
        $stderr.puts "Suitename (#{suitename}) is not configured"
        false
      end

      unless Component.allowed.include?(component)
        $stderr.puts "Component (#{component}) is not configured"
        false
      end

      unless architecture.nil?
        unless Architecture.allowed.include?(architecture)
          $stderr.puts "Architecture (#{architecture}) is not configured"
          false
        end
      end

      @categories.each do |category|
        if category.eql?("stage")
          Component.new(component, suitename, category).create
        else
          unless architecture.nil? || component.nil? || suitename.nil?
            Architecture.new(architecture, component, suitename, category).create
          end
          unless component.nil? || suitename.nil?
            Component.new(component, suitename, category).create
          end
          unless suitename.nil?
            Suite.new(suitename, category).create
          end
        end
      end
    end

    def loop(category)
      structures   = []

      Dir.glob(File.join(@config.get[:rootdir], category, "*")).each do |suitedir|
        suitename = File.split(suitedir)
        Dir.glob(File.join(@config.get[:rootdir], category, suitename[1], "*")).each do |componentdir|
          component = File.split(componentdir)
          if category.eql?("stage")
            structures << { :suitename => suitename[1], :component => component[1]}
          else
            Dir.glob(File.join(@config.get[:rootdir], category, suitename[1], component[1], "*")).each do |architecturedir|
              architecture_dir = File.split(architecturedir)
              architecture = architecture_dir[1].split("-")
              structures << { :suitename => suitename[1], :component => component[1], :architecture_dir => architecture_dir[1], :architecture => architecture[1]}
            end
          end
        end
      end
      structures
    end
  end
end

