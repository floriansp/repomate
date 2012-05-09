require_relative 'configuration'
require_relative 'architecture'
require_relative 'repository'
require_relative 'package'
require 'erb'
require 'date'
require 'time'
require 'gpgme'
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

# RepoMate module
module RepoMate

  # Class that can create and delete all metafiles like Packages, Packages.gz, Release and Release.gpg
  class Metafile

    # Init
    def initialize
      @config     = Configuration.new
      @repository = Repository.new
    end

    # Returns a lit of all existing metafiles as array
    def all
      config   = Configuration.new
      rootdir  = config.get[:rootdir]
      dirlist  = ["#{rootdir}/*/*", "#{rootdir}/*/*/*/*"]
      filelist = ["Packages", "Packages.gz", "Release", "Release.gpg" ]
      files = []

      dirlist.each do |dirs|
        Dir.glob(dirs).each do |dir|
          filelist.each do |file|
            fullname = File.join(dir, file)
            files << fullname if File.exists? fullname
          end
        end
      end
      return files
    end

    # Deletes all existing metafiles
    def destroy
      all.each { |file| FileUtils.rm_f(file) }
    end

    # Creates all metafiles
    def create
      destroy
      create_packages

      if @config.get[:gpg_enable]
        if @config.get[:gpg_password].nil? || @config.get[:gpg_email].nil?
          puts "Configure password and email for GPG!"
          exit 1
        else
          create_release
        end
      end
    end

    # Create Packages* files
    def create_packages
      source_category = "dists"

      packages_template = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/packages.erb")).read, nil, "%"

      Architecture.dataset(source_category).each do |entry|
        source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
        source.files.each do |fullname|
          package = Package.new(fullname, entry[:suitename], entry[:component])

          checksums = package.checksums

          packagesfile = File.join(entry[:fullpath], "Packages")
          size         = File.size(fullname)
          path         = File.join("dists", entry[:suitename], entry[:component], entry[:architecture_dir], package.newbasename)

          File.open(packagesfile, 'a') do |file|
            package.controlfile.each { |key, value| file.puts "#{key}: #{value}" }
            file.puts packages_template.result(binding)
          end
          raise "Could not gzip" unless system "gzip -9 -c #{packagesfile} > #{packagesfile}.gz"
        end
      end
    end

    # Create Release* files
    def create_release
      source_category = "dists"
      suites          = []

      archrelease_template  = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/archrelease.erb")).read, nil, "%"
      suiterelease_template = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/suiterelease.erb")).read, nil, "%"

      now = Time.new.strftime("%a, %d %b %Y %H:%M:%S %Z")

      Architecture.dataset(source_category).each do |entry|
        releasefile = File.join(entry[:fullpath], "Release")

        suites << entry[:suitename] unless suites.include?(entry[:suitename])

        File.open(releasefile, 'w') { |file| file.puts archrelease_template.result(binding) }
      end

      suites.each do |suite|
        architecture = []
        component    = []

        Architecture.dataset(source_category).each do |entry|
          if entry[:suitename].eql?(suite)
            architecture << entry[:architecture] unless architecture.include?(entry[:architecture])
            component << entry[:component] unless component.include?(entry[:component])
          end
        end

        releasefile = File.join(@config.get[:rootdir], source_category, suite, "Release")

        File.open(releasefile, 'w') { |file| file.puts suiterelease_template.result(binding).gsub(/^\s+\n|^\n|^\s{3}/, '') }
        begin
          sign(releasefile)
        rescue
          destroy
          create_packages
          puts "GPG email/password incorrect"
          return
        end
      end
    end

    # Sign a file
    def sign(file)
      crypto = GPGME::Crypto.new :password => @config.get[:gpg_password]
      outfile = "#{file}.gpg"
      output = File.open(outfile, 'w')
      crypto.sign File.open(file, 'r'), :symmetric => false, :output => output, :signer => @config.get[:gpg_email], :mode => GPGME::SIG_MODE_DETACH
    end

  end
end
