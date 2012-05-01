require_relative 'configuration'
require_relative 'repository'
require_relative 'base'
require 'date'
require 'time'

module RepoMate
  class Cli

    def initialize
      @repomate   = Base.new
      @repository = Repository.new
      @config     = Configuration.new
    end

    def setup(options)
      if options.suitename?
        @repository.create(options[:suitename], options[:component], options[:architecture])
      else
        puts "Specify a suitename with [-s|--suitname]"
        exit 0
      end
    end

    def stage(options, filename)
      if options.suitename?
        workload = []
        workload << {:package_fullname => filename, :suitename => options[:suitename], :component => options[:component]}

        puts "Package: #{filename} moving to stage => #{options[:suitename]}/#{options[:component]}"

        @repomate.stage(workload)
      else
        puts "Specify a suitename with [-s|--suitname]"
        exit 0
      end
    end

    def publish(options)
      workload = []
      @repomate.prepare_publish.each do |entry|
        basename  = File.basename(entry[:source_fullname])
        suitename = entry[:suitename]
        component = entry[:component]

        unless options.force?
          printf "\n%s", "Link #{basename} to production => #{suitename}/#{component}? [y|yes|n|no]: "
          input = STDIN.gets
        end

        if options.force? || input =~ /(y|yes)/
          workload << {
            :source_fullname      => entry[:source_fullname],
            :destination_fullname => entry[:destination_fullname],
            :component            => entry[:component],
            :suitename            => entry[:suitename],
            :architecture         => entry[:architecture]
          }
        end
       end
      @repomate.publish(workload) unless workload.empty?
    end

    def save_checkpoint
      # Add verification and some output here
      @repomate.save_checkpoint
    end

    def list_packagelist(options)
      if options.repodir?
        packages = @repomate.get_packagelist(options[:repodir])
        packages.each {|package| printf "%-50s%-20s%s\n", package[:controlfile]['Package'], package[:controlfile]['Version'], "#{package[:suitename]}/#{package[:component]}"}
      else
        puts "Specify a category with [-r|--repodir]"
        exit 0
      end
    end

    def choose_checkpoint
      puts "\n*** Restore production links to a date below. ***
Remember: If you need to restore, the last entry might be the one you want!
Everything between the last two \"publish (-P) commands\" will be lost if you proceed!\n\n"

      list = @repomate.get_checkpoints

      list.each do |num, date|
        datetime = DateTime.parse(date)
        puts "#{num}) #{datetime.strftime("%F %T")}"
      end

      printf "\n%s", "Enter number or [q|quit] to abord: "
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
end

