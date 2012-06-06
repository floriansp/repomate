require 'date'
require 'time'

# RepoMate module
module RepoMate

  # Class for the commandline interface
  class Cli

    # Init
    def initialize
      @repomate   = Base.new
      @repository = Repository.new
      @checkpoint = Checkpoint.new
    end

    # Sets up the base directory structure by calling the repository class
    def setup(options)
      if options.suitename?
        @repository.create(options[:suitename], options[:component], options[:architecture])
      else
        STDERR.puts "Specify a suitename with [-s|--suitname]"
        exit 1
      end
    end

    # Adds a given package to the staging area by calling the base class
    def stage(options, filename)
      if options.suitename?
        workload = []
        workload << {:package_fullname => filename, :suitename => options[:suitename], :component => options[:component]}

        puts "Package: #{filename} moving to stage => #{options[:suitename]}/#{options[:component]}"

        @repomate.stage(workload)
      else
        STDERR.puts "Specify a suitename with [-s|--suitname]"
        exit 1
      end
    end

    # Get's all packages from the staging area. Packages need to be confirmed here.
    def publish(options)
      action = true
      @repomate.prepare_publish.each do |entry|
        workload  = []
        basename  = File.basename(entry[:source_fullname])
        suitename = entry[:suitename]
        component = entry[:component]

        unless options.force?
          printf "\n%s", "Link #{basename} to production => #{suitename}/#{component}? [y|yes|n|no]: "
          input = STDIN.gets
        end

        if options.force? || input =~ /(y|yes)/
          @checkpoint.create if action

          action = false

          workload << {
            :source_fullname      => entry[:source_fullname],
            :destination_fullname => entry[:destination_fullname],
            :component            => entry[:component],
            :suitename            => entry[:suitename],
            :architecture         => entry[:architecture]
          }
        end

        @repomate.publish(workload) unless workload.empty?
       end
    end

    # Save a checkpoint
    def save_checkpoint
      # Add verification and some output here
      @checkpoint.create
    end

    # List all packages, see cli output
    def list_packages(repodir)
      if repodir
        architecture = "unknown"

        packages = @repomate.list_packages(repodir)
        packages.each do |package|
            architecture = package[:architecture] if package[:architecture]
            printf "%-50s%-20s%s\n", package[:controlfile]['Package'], package[:controlfile]['Version'], "#{package[:suitename]}/#{package[:component]}/#{architecture}"
        end
      else
        STDERR.puts "Specify a category with [-r|--repodir]"
        exit 1
      end
    end

    # Choose a checkpoint to restore.
    def choose_checkpoint
      list = @checkpoint.list

      if list.empty?
        STDERR.puts "We can't restore because we don't have checkpoints"
        exit 1
      end

      puts "\n*** Restore production links to a date below. ***
Remember: If you need to restore, the last entry might be the one you want!
Everything between the last two \"publish (-P) commands\" will be lost if you proceed!\n\n"

      list.each do |num, date|
        datetime = DateTime.parse(date)
        puts "#{num}) #{datetime.strftime("%F %T")}"
      end

      printf "\n%s", "Enter number or [q|quit] to abord: "
      input  = STDIN.gets
      number = input.to_i

      if input =~ /(q|quit)/
        puts "Aborting..."
        exit 0
      elsif list[number].nil?
        STDERR.puts "Invalid number"
        exit 1
      else
        @checkpoint.load(number)
      end
    end

    # Choose a package
    def choose_package(action)
      packages  = @repomate.list_packages("dists")
      packages.each do |package|
        printf "%d) %-50s%-20s%s\n", package[:number], package[:controlfile]['Package'], package[:controlfile]['Version'], "#{package[:suitename]}/#{package[:component]}"
      end

      printf "\n%s", "Enter number or [q|quit] to abord: "
      input  = STDIN.gets
      number = input.to_i

      if input =~ /(q|quit)/
        puts "Aborting..."
        exit 0
      else
        packages.each do |package|
          if package[:number].eql?(number)
            @repomate.remove(package) if action.eql?("remove")
          end
        end
      end
    end
  end
end

