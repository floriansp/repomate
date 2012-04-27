require 'date'
require 'time'
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'
require_relative 'configuration'
require_relative 'packages'
require_relative 'pool'

class RepoMate
  def initialize
    @config = Configuration.new
  end

  def stage(source_fullname, suitename)
    package              = Package.new(source_fullname, suitename)
    destination_fullname = File.join(pool.stage_dir(suitename), package.newbasename)

    pool.setup(suitename)

    puts "Package: #{package.newbasename} moved to stage/#{suitename}"

    FileUtils.copy(source_fullname, destination_fullname)
  end

  def publish
    pool.active_suites.each do |suitename|
      debfiles = File.join(pool.stage_dir(suitename), "*.deb")

      Dir.glob(debfiles) do |source_fullname|
        package              = Package.new(source_fullname, suitename)
        destination_fullname = File.join(pool.pool_dir(suitename), package.newbasename)

        FileUtils.move(source_fullname, destination_fullname)

        source_fullname = destination_fullname

        link(source_fullname, pool.production_dir(suitename), suitename)
      end
    end
  end

  def save_checkpoint
    File.open(@config.get[:redolog], 'a') do |file|
      pool.active_suites.each do |suitename|
        debfiles = File.join(pool.production_dir(suitename), "*.deb")
        Dir.glob(debfiles) do |fullname|
          basename = File.basename(fullname)
          file.puts "#{DateTime.now} #{suitename} #{basename}"
        end
      end
    end
  end

  def load_checkpoint
    unless File.exists?(@config.get[:redolog])
      puts "We can't restore because we don't have checkpoints"
      exit 1
    end

    puts "\n*** Restore production links to a date below. ***
Remember: If you need to restore, the last entry might be the one you want!
Everything between the last two \"unstage (-u) commands\" will be lost if you proceed!\n\n"

    order = 0
    dates = []
    list  = {}

    File.open(@config.get[:redolog], 'r') do |file|
      while (line = file.gets)
        dates << line.split[0] unless dates.include?(line.split[0])
      end
    end

    dates.each do |date|
      order += 1
      list[order] = date
    end

    list.each do |num, date|
      datetime = DateTime.parse(date)
      ddate = datetime.strftime("%F %T")
      puts "#{num}) #{ddate}"
    end

    puts "\nEnter number or [q|quit] to abord: "
    input  = STDIN.gets
    number = input.to_i

    if input =~ /(q|quit)/
      STDERR.puts "Aborting..."
      exit 0
    elsif list[number].nil?
      STDERR.puts "Invalid number"
      exit 0
    else
      pool.active_suites.each do |suitename|
        debfiles = File.join(pool.production_dir(suitename), "*.deb")
        Dir.glob(debfiles) do |fullname|
          File.unlink fullname
        end
      end

      puts "\nRestoring...\n"

      File.open(@config.get[:redolog], 'r') do |file|
        while (line = file.gets)
          if line.split[0] == list[number]
            basename     = line.split[2]
            suitename    = line.split[1]
            poolbasename = File.join(pool.pool_dir(suitename), basename)

            link(poolbasename, pool.production_dir(suitename), suitename)
          end
        end
      end
      scan_packages
    end
  end

  def scan_packages
  # TODO: systemcall or better gem for digest stuff
    pool.active_suites.each do |suitename|
      packages    = File.join(pool.production_dir(suitename), "Packages")
      packages_gz = File.join(pool.production_dir(suitename), "Packages.gz")
      debfiles    = File.join(pool.production_dir(suitename), "*.deb")

      File.unlink(packages_gz) if File.exists?(packages_gz)

      Dir.glob(debfiles) do |fullname|
        package = Package.new(fullname, suitename)

        File.open(packages, 'a') do |file|
          package.controlfile.each do |key, value|
            file.puts "#{key}: #{value}"
          end
          file.puts "MD5sum: #{Digest::MD5.file(fullname).to_s}"
          file.puts "SHA1: #{Digest::SHA1.file(fullname).to_s}"
          file.puts "SHA256: #{Digest::SHA256.new(256).file(fullname).to_s}\n\n"
        end
      end
      if File.exists?(packages)
        raise "Could not gzip" unless system "gzip -9 -c #{packages} >> #{packages_gz}"
      end
    end
  end

  def list_packages(*suitename)
    if suitename.empty?
      pool.active_suites.each do |suitename|
        list_packages_by_suite(suitename)
      end
    else
      list_packages_by_suite(suitename)
    end
  end

  def list_packages_by_suite(suitename)
    debfiles = File.join(pool.pool_dir(suitename), "*.deb")

    puts "Active packages in #{suitename}:"

    Dir.glob(debfiles) do |source_fullname|
      package = Package.new(source_fullname, suitename)

      basename     = package.controlfile['Package']
      version      = package.controlfile['Version']
      description  = package.controlfile['Description']

      printf "%s%50s%15s\n", basename, version, suitename
    end
  end

  protected

  def pool
    @pool ||= Pool.new
  end

  def link(source_fullname, destination_dir, suitename)
    source_package = Package.new(source_fullname, suitename)
    source_version = source_package.controlfile['Version']
    debfiles       = "#{destination_dir}/#{source_package.controlfile['Package']}*.deb"
    action         = 1
    dpkg           = @config.get[:dpkg]

    raise "dpkg is not installed" unless File.exists?(dpkg)

    Dir.glob(debfiles) do |destination_fullname|
      destination_package = Package.new(destination_fullname, suitename)
      destination_version = destination_package.controlfile['Version']

      if system("#{dpkg} --compare-versions #{source_version} gt #{destination_version}")
        puts "Package: #{destination_package.newbasename} replaced with #{source_package.newbasename}."
        File.unlink(destination_fullname)
      elsif system("#{dpkg} --compare-versions #{source_version} eq #{destination_version}")
        puts "Package: #{source_package.newbasename} already exists with same version."
        action = nil
      elsif system("#{dpkg} --compare-versions #{source_version} lt #{destination_version}")
        puts "Package: #{source_package.newbasename} already exists with higher version."
        action = nil
      end
    end

    if not action.nil?
      save_checkpoint

      destination_fullname = File.join(destination_dir, source_package.newbasename)
      puts "Package: #{source_package.newbasename} linked to production/#{suitename}"

      File.symlink(source_fullname, destination_fullname)

      scan_packages
    end
  end
end
