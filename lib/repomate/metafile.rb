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

module RepoMate
  class Metafile

    def initialize
      @config     = Configuration.new
      @repository = Repository.new
    end

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

    def destroy
      all.each do |file|
        FileUtils.rm_f(file)
      end
    end

    def create
      destroy

      source_category = "dists"

      now = Time.new.strftime("%a, %d %b %Y %H:%M:%S %Z")

      packages_template     = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/packages.erb")).read, nil, "%"
      archrelease_template  = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/archrelease.erb")).read, nil, "%"
      suiterelease_template = ERB.new File.new(File.join(File.dirname(__FILE__), "templates/suiterelease.erb")).read, nil, "%"

      Architecture.dataset(source_category).each do |entry|
        source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
        source.files.each do |fullname|
          package = Package.new(fullname, entry[:suitename], entry[:component])

          packagesfile = File.join(entry[:fullpath], "Packages")
          size         = File.size(fullname)
          path         = File.join("dists", entry[:suitename], entry[:component], entry[:architecture_dir], package.newbasename)

          File.open(packagesfile, 'a') do |file|
            package.controlfile.each do |key, value|
              file.puts "#{key}: #{value}"
            end

            file.puts packages_template.result(binding)
          end
          raise "Could not gzip" unless system "gzip -9 -c #{packagesfile} > #{packagesfile}.gz"
        end
      end

      if @config.get[:gpg_enable]
        if @config.get[:gpg_password].nil? || @config.get[:gpg_email].nil?
          puts "Configure password and email for GPG!"
          exit 1
        else
          Architecture.dataset(source_category).each do |entry|
            source      = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], source_category)
            releasefile = File.join(entry[:fullpath], "Release")

            File.open(releasefile, 'w') do |file|
              file.puts archrelease_template.result(binding)
            end
          end

          Suite.names.each do |suite|
            Suite.dataset(source_category).each do |entry|
              source      = Suite.new(suite, "dists")
              releasefile = File.join(entry[:fullpath], "Release")

              File.open(releasefile, 'w') do |file|
                file.puts suiterelease_template.result(binding).gsub(/^\s+/, '')
              end

              crypto = GPGME::Crypto.new :password => @config.get[:gpg_password]
              file = "#{releasefile}.gpg"
              output = File.open(file, 'w')
              crypto.clearsign File.open(releasefile, 'r'), :symmetric => true, :output => output, :signer => @config.get[:gpg_email], :mode => GPGME::SIG_MODE_DETACH
            end
          end
        end
      end
    end
  end
end
