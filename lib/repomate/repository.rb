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
        exit 1
      end

      unless Component.allowed.include?(component)
        $stderr.puts "Component (#{component}) is not configured"
        exit 1
      end

      unless architecture.nil?
        unless Architecture.allowed.include?(architecture)
          $stderr.puts "Architecture (#{architecture}) is not configured"
          exit 1
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
  end
end

