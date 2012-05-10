# require 'repomate/configuration'
# require 'repomate/architecture'
# require 'repomate/component'
# require 'repomate/category'
# require 'repomate/suite'

# RepoMate module
module RepoMate

  # Class for creating the repository structure
  class Repository

    attr_reader :categories

    # Init
    def initialize
      @config     = Configuration.new
      @categories = ["stage", "pool", "dists"]
    end

    # Creates the base structure
    def create(suitename=nil, component=nil, architecture=nil)
      unless Suite.allowed.include?(suitename)
        STDERR.puts "Suitename (#{suitename}) is not configured"
        exit 1
      end

      unless Component.allowed.include?(component)
        STDERR.puts "Component (#{component}) is not configured"
        exit 1
      end

      unless architecture.nil?
        unless Architecture.allowed.include?(architecture)
          STDERR.puts "Architecture (#{architecture}) is not configured"
          exit 1
        end
      end

      @categories.each do |category|
        if category.eql?("stage")
          Component.new(component, suitename, category).create
        else
          if architecture && component && suitename
            Architecture.new(architecture, component, suitename, category).create
          elsif component && suitename
            Component.new(component, suitename, category).create
          elsif suitename.nil?
            Suite.new(suitename, category).create
          end
        end
      end
    end
  end
end

