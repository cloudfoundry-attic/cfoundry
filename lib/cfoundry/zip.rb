require "zip/zipfilesystem"

module CFoundry
  # Generic Zpi API. Uses rubyzip underneath, but may be changed in the future
  # to use system zip command if necessary.
  module Zip
    # Directory entries to exclude from packing.
    PACK_EXCLUSION_GLOBS = ['..', '.', '*~', '#*#', '*.log']

    module_function

    # Get the entries in the zip file. Returns an array of the entire
    # contents, recursively (not just top-level).
    def entry_lines(file)
      entries = []
      ::Zip::ZipFile.foreach(file) do |zentry|
        entries << zentry
      end
      entries
    end

    # Unpack a zip +file+ to directory +dest+.
    def unpack(file, dest)
      ::Zip::ZipFile.foreach(file) do |zentry|
        epath = "#{dest}/#{zentry}"
        dirname = File.dirname(epath)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        zentry.extract(epath) unless File.exists?(epath)
      end
    end

    # Determine what files in +dir+ to pack.
    def files_to_pack(dir)
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select do |f|
        File.exists?(f) &&
          PACK_EXCLUSION_GLOBS.none? do |e|
            File.fnmatch(e, File.basename(f))
          end
      end
    end

    # Package directory +dir+ as file +zipfile+.
    def pack(dir, zipfile)
      files = files_to_pack(dir)
      return false if files.empty?

      ::Zip::ZipFile.open(zipfile, true) do |zf|
        files.each do |f|
          zf.add(f.sub("#{dir}/",''), f)
        end
      end

      true
    end
  end
end
