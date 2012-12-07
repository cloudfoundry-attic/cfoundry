require "tmpdir"
require "fileutils"
require "pathname"
require "digest/sha1"

require "cfoundry/zip"

module CFoundry
  module UploadHelpers
    # Default paths to exclude from upload payload.
    UPLOAD_EXCLUDE = %w{.git _darcs .svn}

    # Minimum size for an application payload to bother checking resources.
    RESOURCE_CHECK_LIMIT = 64 * 1024

    # Upload application's code to target. Do this after #create! and before
    # #start!
    #
    # [path]
    #   A path pointing to either a directory, or a .jar, .war, or .zip
    #   file.
    #
    #   If a .vmcignore file is detected under the given path, it will be used
    #   to exclude paths from the payload, similar to a .gitignore.
    #
    # [check_resources]
    #   If set to `false`, the entire payload will be uploaded
    #   without checking the resource cache.
    #
    #   Only do this if you know what you're doing.
    def upload(path, check_resources = true)
      unless File.exist? path
        raise CFoundry::Error, "Invalid application path '#{path}'"
      end

      zipfile = "#{Dir.tmpdir}/#{@guid}.zip"
      tmpdir = "#{Dir.tmpdir}/.vmc_#{@guid}_files"

      FileUtils.rm_f(zipfile)
      FileUtils.rm_rf(tmpdir)

      prepare_package(path, tmpdir)

      resources = determine_resources(tmpdir) if check_resources

      packed = CFoundry::Zip.pack(tmpdir, zipfile)

      @client.base.upload_app(@guid, packed && zipfile, resources || [])
    ensure
      FileUtils.rm_f(zipfile) if zipfile
      FileUtils.rm_rf(tmpdir) if tmpdir
    end

    def prepare_package(path, to)
      if path =~ /\.(jar|war|zip)$/
        CFoundry::Zip.unpack(path, to)
      elsif war_file = Dir.glob("#{path}/*.war").first
        CFoundry::Zip.unpack(war_file, to)
      else
        check_unreachable_links(path)

        FileUtils.mkdir(to)

        files = Dir.glob("#{path}/{*,.[^\.]*}")

        exclude = UPLOAD_EXCLUDE
        if File.exists?("#{path}/.vmcignore")
          exclude += File.read("#{path}/.vmcignore").split(/\n+/)
        end

        # prevent initial copying if we can, remove sub-files later
        files.reject! do |f|
          exclude.any? do |e|
            File.fnmatch(f.sub(path + "/", ""), e)
          end
        end

        FileUtils.cp_r(files, to)

        find_sockets(to).each do |s|
          File.delete s
        end

        # remove ignored globs more thoroughly
        #
        # note that the above file list only includes toplevel
        # files/directories for cp_r, so this is where sub-files/etc. are
        # removed
        exclude.each do |e|
          Dir.glob("#{to}/#{e}").each do |f|
            FileUtils.rm_rf(f)
          end
        end
      end
    end

    def check_unreachable_links(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)

      # only used for friendlier error message
      pwd = Pathname.pwd

      abspath = File.expand_path(path)
      unreachable = []
      files.each do |f|
        file = Pathname.new(f)
        if file.symlink? && !file.realpath.to_s.start_with?(abspath)
          unreachable << file.relative_path_from(pwd)
        end
      end

      unless unreachable.empty?
        root = Pathname.new(path).relative_path_from(pwd)
        raise CFoundry::Error,
          "Path contains links '#{unreachable}' that point outside '#{root}'"
      end
    end

    def find_sockets(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)
      files && files.select { |f| File.socket? f }
    end

    def determine_resources(path)
      fingerprints, total_size = make_fingerprints(path)

      return if total_size <= RESOURCE_CHECK_LIMIT

      resources = @client.base.resource_match(fingerprints)

      resources.each do |resource|
        FileUtils.rm_f resource[:fn]
        resource[:fn].sub!("#{path}/", "")
      end

      resources
    end

    def make_fingerprints(path)
      fingerprints = []
      total_size = 0

      Dir.glob("#{path}/**/*", File::FNM_DOTMATCH) do |filename|
        next if File.directory?(filename)

        size = File.size(filename)

        total_size += size

        fingerprints << {
          :size => size,
          :sha1 => Digest::SHA1.file(filename).hexdigest,
          :fn => filename
        }
      end

      [fingerprints, total_size]
    end
  end
end
