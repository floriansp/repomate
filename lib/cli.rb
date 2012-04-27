require 'date'
require 'time'
require_relative 'repomate'
require_relative 'configuration'
require_relative 'packages'
require_relative 'pool'

class Cli
  def initialize
    @repomate = RepoMate.new
    @pool     = Pool.new
    @config   = Configuration.new
  end

  def list_packages(suitename=nil)
    if suitename.nil?
      @pool.structure.each do |suitename, components|
        components.each do |component|
          list_packages_by_suite(suitename, component)
        end
      end
    else
      list_packages_by_suite(suitename, component)
    end
  end

  def list_packages_by_suite(suitename, component)
    debfiles = File.join(@pool.pool_dir(suitename, component), "*.deb")
    Dir.glob(debfiles) do |source_fullname|
      package = Package.new(source_fullname, suitename)

      basename    = package.controlfile['Package']
      version     = package.controlfile['Version']
      description = package.controlfile['Description']

      printf "%-50s%-20s%s\n", basename, version, "#{suitename}/#{component}"
    end
  end

  def publish
    input = nil

    @pool.structure.each do |suitename, components|
      components.each do |component|
        debfiles = File.join(@pool.stage_dir(suitename, component), "*.deb")

        Dir.glob(debfiles) do |source_fullname|
          package              = Package.new(source_fullname, suitename)
          destination_fullname = File.join(@pool.pool_dir(suitename, component), package.newbasename)

          printf "\n%s", "\nLink #{package.newbasename} to production => #{suitename}/#{component}? [y|yes|n|no]: "
          input = STDIN.gets

          if input =~ /(y|yes)/
            @repomate.publish(source_fullname, destination_fullname, suitename, component)
          end
        end
      end
    end
  end

  def load_checkpoint
    puts "\n*** Restore production links to a date below. ***
Remember: If you need to restore, the last entry might be the one you want!
Everything between the last two \"unstage (-u) commands\" will be lost if you proceed!\n\n"

    list = @repomate.list_checkpoints

    list.each do |num, date|
      datetime = DateTime.parse(date)
      ddate = datetime.strftime("%F %T")
      puts "#{num}) #{ddate}"
    end

    printf "\n%s", "\nEnter number or [q|quit] to abord: "
    input  = STDIN.gets
    number = input.to_i

    if input =~ /(q|quit)/
      STDERR.puts "Aborting..."
      exit 0
    elsif list[number].nil?
      STDERR.puts "Invalid number"
      exit 0
    else
      @repomate.load_checkpoint(number)
    end
  end
end
