require_relative 'configuration'
require_relative 'architecture'
require_relative 'repository'
require_relative 'package'
require 'date'
require 'time'
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'

module RepoMate
  class Metafile

    def initialize
      @config     = Configuration.new
      @repository = Repository.new
    end

    def create
      @repository.loop("dists").each do |entry|
        destination = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")

        packages    = File.join(destination.directory, "Packages")
        packages_gz = File.join(destination.directory, "Packages.gz")

        File.unlink(packages) if File.exists?(packages)

        destination.files.each do |fullname|
          package = Package.new(fullname, entry[:suitename], entry[:component])

          File.open(packages, 'a') do |file|
            package.controlfile.each do |key, value|
              file.puts "#{key}: #{value}"
            end

            # temp
            size = File.size(fullname)

            file.puts "Size: #{size}"
            file.puts "Filename: dists/#{entry[:suitename]}/#{entry[:component]}/#{entry[:architecture_dir]}/#{package.newbasename}"
            file.puts "MD5sum: #{Digest::MD5.file(fullname).to_s}"
            file.puts "SHA1: #{Digest::SHA1.file(fullname).to_s}"
            file.puts "SHA256: #{Digest::SHA256.new(256).file(fullname).to_s}\n\n"
          end
        end
        if File.exists?(packages)
          raise "Could not gzip" unless system "gzip -9 -c #{packages} > #{packages_gz}"
        end
      end

      release          = "Release"
      origin           = @config.get[:origin]
      label            = @config.get[:label]
      suites           = []
      components       = []
      architectures    = []
      architecturedirs = []


      @repository.loop("dists").each do |entry|
        source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")

        suites << entry[:suitename] unless suites.include?(entry[:suitename])
        components << entry[:component] unless components.include?(entry[:component])
        architectures << entry[:architecture] unless architectures.include?(entry[:architecture])
        architecturedirs << entry[:architecture_dir] unless architecturedirs.include?(entry[:architecture_dir])

        File.open(File.join(source.directory, release), 'w') do |file|
          file.puts "Archive: stable"
          file.puts "Component: #{entry[:component]}"
          file.puts "Origin: #{origin}"
          file.puts "Label: #{label}"
          file.puts "Architecture: #{entry[:architecture]}"
          file.puts "Description: Repository for debian #{entry[:suitename]}"
        end
      end

      dt = Time.new.strftime("%a, %d %b %Y %H:%M:%S %Z")

      suitesline = suites.join ', '
      componentline = components.join ', '
      architectureline = architectures.join ', '

      suites.each do |suite|
        source = Suite.new(suite, "dists")

        File.open(File.join(source.directory, release), 'w') do |file|
          file.puts "Origin: #{origin}"
          file.puts "Label: #{label}"
          file.puts "Suite: stable"
          file.puts "Codename: #{source.name}"
          file.puts "Date: #{dt}"
          file.puts "Architectures: #{architectureline}"
          file.puts "Components: #{componentline}"
          file.puts "Description: Repository for debian #{suitesline}"
          file.puts "MD5Sum:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::MD5.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::MD5.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end

          file.puts "SHA1:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA1.file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end

          file.puts "SHA256:"

          @repository.loop("dists").each do |entry|
            source  = Architecture.new(entry[:architecture], entry[:component], entry[:suitename], "dists")
            source.packagesfiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA256.new(256).file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
            source.releasefiles.each do |fullname|
              basename = File.split(fullname)[1]
              file.puts " #{Digest::SHA256.new(256).file(fullname).to_s} #{File.size(fullname)} #{entry[:component]}/#{entry[:architecture_dir]}/#{basename}"
            end
          end
        end
      end

      # Add something like gpg -a --yes -u $KEY -b -o dists/squeeze/Release.gpg dists/squeeze/Release here

    end
  end
end
