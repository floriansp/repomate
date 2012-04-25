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

  def stage(fullname, distname)
    package       = Package.new(fullname, distname)
    stagefullname = File.join(pool.stagedir(distname), package.newbasename)

    pool.setup(distname)

    puts "Package: #{package.newbasename} moved to stage/#{distname}"

    FileUtils.copy(fullname, stagefullname)
  end

  def unstage
    #publish

    save

    pool.activedistributions.each do |distname|
      debs = File.join(pool.stagedir(distname), "*.deb")

      Dir.glob(debs) do |fullname|
        package         = Package.new(fullname, distname)
        archivefullname = File.join(pool.archivedir(distname), package.newbasename)

        FileUtils.move(fullname, archivefullname)
        link(archivefullname, pool.productiondir(distname), distname)
      end
    end
  end

  def save

    File.open(@config.get[:redolog], 'a') do |file|
      pool.activedistributions.each do |distname|
        debs = File.join(pool.productiondir(distname), "*.deb")
        Dir.glob(debs) do |fullname|
          basename = File.basename(fullname)
          file.puts "#{DateTime.now} #{distname} #{basename}"
        end
      end
    end
  end

  def load
    unless File.exists?(@config.get[:redolog])
      puts "We can't restore because we don't have checkpoints"
      exit 1
    end

    puts "*** Restore production links to a date below. ***
Remember: If you need to restore, the last entry might be the one you want!
Everything between the last two \"unstage (-u) commands\" will be lost if you proceed!\n\n"

    order = 0
    dates = []
    list  = {}

    File.open(@config.get[:redolog], 'r') do |file|
      while (line = file.gets)
        dates.push(line.split[0]) unless dates.include?(line.split[0])
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

    printf "\n%s","Enter number or [q|quit] to abord: "
    input  = STDIN.gets
    number = input.to_i

    if input =~ /[q|quit]/
      STDERR.puts "Aborting..."
      exit 0
    elsif list[number].nil?
      STDERR.puts "Invalid number"
      exit 0
    else
      pool.activedistributions.each do |distname|
        debs = File.join(pool.productiondir(distname), "*.deb")
        Dir.glob(debs) do |fullname|
          File.unlink fullname
        end
      end

      printf "\n%s\n", "Restoring..."

      File.open(@config.get[:redolog], 'r') do |file|
        while (line = file.gets)
          if line.split[0] == list[number]
            basename        = line.split[2]
            distname        = line.split[1]
            archivebasename = File.join(pool.archivedir(distname), basename)

            link(archivebasename, pool.productiondir(distname), distname)
          end
        end
      end
      scan_packages
    end
  end

  def scan_packages
# systemcall md5 usw. oder gem suchen?

    pool.activedistributions.each do |distname|
      packages    = File.join(pool.productiondir(distname), "Packages")
      packages_gz = File.join(pool.productiondir(distname), "Packages.gz")
      debs        = File.join(pool.productiondir(distname), "*.deb")

      File.unlink(packages_gz) if File.exists?(packages_gz)

      Dir.glob(debs) do |fullname|
        package = Package.new(fullname, distname)

        File.open(packages, 'a') do |file|
          package.controlfile.each do |key, value|
            #file.printf "%s: %s\n", key, value
            file.puts "#{key}: #{value}"
          end
          file.printf "%s: %s\n", "MD5sum", Digest::MD5.file(fullname).to_s
          file.printf "%s: %s\n", "SHA1", Digest::SHA1.file(fullname).to_s
          file.printf "%s: %s\n\n", "SHA256", Digest::SHA256.new(256).file(fullname).to_s
          # puts -> \n\n
        end
      end
      if File.exists?(packages)
        raise "Could not gzip" unless system "gzip -9 -f #{packages}"
      end
    end
  end

  protected

  def pool
    @pool ||= Pool.new
  end

  def versions(version)
    s = version.gsub(/\./, "")
    s =~ %r{(\d+).*(\d+)}

    [$1,$2]
  end

  def link(fullname_a, productiondir, distname)
    package_a    = Package.new(fullname_a, distname)
    versions_a   = versions(package_a.controlfile['Version'])
    debs         = "#{productiondir}/#{package_a.controlfile['Package']}*.deb"
    prodfullname = File.join(productiondir, package_a.newbasename)

    Dir.glob(debs) do |fullname_b|
      package_b  = Package.new(fullname_b, distname)
      versions_b = versions(package_b.controlfile['Version'])
      if versions_a[0] == versions_b[0] && versions_a[1] > versions_b[1]
        puts "Package: #{package_b.newbasename} replaced with #{package_a.newbasename}."
        File.unlink(fullname_b)
      elsif versions_a[0] > versions_b[0]
        puts "Package: #{package_b.newbasename} replaced with #{package_a.newbasename}."
        File.unlink(fullname_b)
      elsif versions_a[0] == versions_b[0] && versions_a[1] == versions_b[1]
        puts "Package: #{package_a.newbasename} already exists with same version numbers"
      else
        puts "something else happend"
      end
    end

    unless File.exists?(prodfullname)
      puts "Package: #{package_a.newbasename} linked to production/#{distname}"

      File.symlink(fullname_a, prodfullname)
    end
    scan_packages
  end
end
