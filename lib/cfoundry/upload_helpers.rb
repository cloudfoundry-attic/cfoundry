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
    #   If a .cfignore file is detected under the given path, it will be used
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
      tmpdir = "#{Dir.tmpdir}/.cf_#{@guid}_files"

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

    private

    def prepare_package(path, to)
      archive = find_archives_in_path(path)
      if (archive.length == 1)
        CFoundry::Zip.unpack(archive.first, to)
      else
        FileUtils.mkdir(to)

        exclude = UPLOAD_EXCLUDE
        if File.exists?("#{path}/.cfignore")
          exclude += File.read("#{path}/.cfignore").split(/\n+/)
        end

        files = files_to_consider(path, exclude)

        check_unreachable_links(files, path)

        copy_tree(files, path, to)

        find_sockets(to).each do |s|
          File.delete s
        end
      end
    end

    def find_archives_in_path(path)
      files = Array.new
      list = Array.new
      if File.file?(path)
        files << path
      else
        files = Dir.glob(File.join(path, '*'))
      end

      files.each do |file|
        if File.file?(file)
          File.open(file, 'r') do |fil|
            prefix = fil.read(2)
            list << file if prefix == 'PK'
          end
        end
      end
      list
    end

    def check_unreachable_links(files, path)
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

    def files_to_consider(path, exclusions)
      entries = all_files(path)

      exclusions.each do |exclusion|
        ignore_pattern = exclusion.start_with?("/") ? File.join(path, exclusion) : File.join(path, "**", exclusion)
        dir_glob = Dir.glob(ignore_pattern, File::FNM_DOTMATCH)
        entries -= dir_glob

        ignore_pattern = File.join(path, "**", exclusion, "**", "*")
        dir_glob = Dir.glob(ignore_pattern, File::FNM_DOTMATCH)
        entries -= dir_glob
      end

      entries
    end

    def glob_matches?(file, path, pattern)
      name = file.sub("#{path}/", "/")
      flags = File::FNM_DOTMATCH

      # when pattern ends with /, match only directories
      if pattern.end_with?("/") && File.directory?(file)
        name = "#{name}/"
      end

      case pattern
      # when pattern contains /, do a pathname match
      when /\/./
        flags |= File::FNM_PATHNAME

      # otherwise, match any file path
      else
        pattern = "**/#{pattern}"
      end

      File.fnmatch(pattern, name, flags)
    end

    def find_sockets(path)
      all_files(path).select { |f| File.socket? f }
    end

    def determine_resources(path)
      fingerprints, total_size = make_fingerprints(path)

      return if total_size <= RESOURCE_CHECK_LIMIT

      resources = @client.base.resource_match(fingerprints)

      resources.each do |resource|
        FileUtils.rm_f resource[:fn]
        resource[:fn].sub!("#{path}/", "")
      end

      prune_empty_directories(path)

      resources
    end

    # OK, HERES THE PLAN...
    #
    # 1. Get all the directories in the entire file tree.
    # 2. Sort them by the length of their absolute path.
    # 3. Go through the list, longest paths first, and remove
    #    the directories that are empty.
    #
    # This ensures that directories containing empty directories
    # are also pruned.
    def prune_empty_directories(path)
      all_files = all_files(path)

      directories = all_files.select { |x| File.directory?(x) }
      directories.sort! { |a, b| b.size <=> a.size }

      directories.each do |directory|
        entries = all_files(directory)
        FileUtils.rmdir(directory) if entries.empty?
      end
    end

    def make_fingerprints(path)
      fingerprints = []
      total_size = 0

      all_files(path).each do |filename|
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

    def all_files(path)
      Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).reject do |fn|
        fn =~ /\.$/
      end
    end

    def copy_tree(files, path, to)
      files.each do |file|
        dest = file.sub("#{path}/", "#{to}/")

        if File.directory?(file)
          FileUtils.mkdir_p(dest)
        else
          destdir = File.dirname(dest)
          FileUtils.mkdir_p(destdir)
          FileUtils.cp(file, dest)
        end
      end
    end
  end
end
