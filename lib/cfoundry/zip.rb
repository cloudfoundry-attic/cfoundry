require 'zip/zipfilesystem'

module CFoundry
  module Zip
    PACK_EXCLUSION_GLOBS = ['..', '.', '*~', '#*#', '*.log']

    module_function

    def entry_lines(file)
      entries = []
      ::Zip::ZipFile.foreach(file) do |zentry|
        entries << zentry
      end
      entries
    end

    def unpack(file, dest)
      ::Zip::ZipFile.foreach(file) do |zentry|
        epath = "#{dest}/#{zentry}"
        dirname = File.dirname(epath)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        zentry.extract(epath) unless File.exists?(epath)
      end
    end

    def files_to_pack(dir)
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select do |f|
        File.exists?(f) &&
          PACK_EXCLUSION_GLOBS.none? do |e|
            File.fnmatch(e, File.basename(f))
          end
      end
    end

    def pack(dir, zipfile)
      ::Zip::ZipFile.open(zipfile, true) do |zf|
        files_to_pack(dir).each do |f|
          zf.add(f.sub("#{dir}/",''), f)
        end
      end
    end
  end
end
