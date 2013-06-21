require "spec_helper"

class TestModelWithUploadHelpers < CFoundry::V2::Model
  include CFoundry::UploadHelpers
end

module CFoundry
  describe UploadHelpers do
    describe "#upload" do
      def relative_glob(dir)
        base_pathname = Pathname.new(dir)
        Dir["#{dir}/**/{*,.[^\.]*}"].map do |file|
          Pathname.new(file).relative_path_from(base_pathname).to_s
        end
      end

      def mock_zip(*args, &block)
        if args.empty?
          CFoundry::Zip.should_receive(:pack, &block)
        else
          CFoundry::Zip.should_receive(:pack).with(*args, &block)
        end
      end

      let(:base) { Object.new }
      let(:guid) { "123" }
      let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_cfignore" }
      let(:check_resources) { false }
      let(:tmpdir) { "#{SPEC_ROOT}/tmp/fake_tmpdir" }

      let(:client) { build(:client) }

      let(:model) { TestModelWithUploadHelpers.new(guid, client) }

      before do
        client.stub(:base) { base }
        base.stub(:upload_app)

        FileUtils.rm_rf tmpdir
        Dir.stub(:tmpdir) do
          FileUtils.mkdir_p tmpdir
          tmpdir
        end
      end

      it "zips the app and uploads the zip file" do
        zip_path = "#{tmpdir}/#{guid}.zip"
        mock_zip(anything, zip_path) { true }
        base.stub(:upload_app).with(guid, zip_path, [])
        model.upload(path, check_resources)
      end

      it "uploads an app with the right guid" do
        mock_zip
        base.should_receive(:upload_app).with(guid, anything, anything)
        model.upload(path, check_resources)
      end

      it "uses a unique directory name when it copies the app" do
        mock_zip(/#{tmpdir}.*#{guid}.*/, anything)
        model.upload(path, check_resources)
      end

      it "cleans up after itself correctly" do
        model.upload(path, check_resources)
        expect(relative_glob(tmpdir)).to be_empty
      end

      it "includes the source files of the app in the zip file" do
        mock_zip do |src, _|
          files = relative_glob(src)
          expect(files).to include "non_ignored_dir"
          expect(files).to include "non_ignored_file.txt"
          expect(files).to include "non_ignored_dir/file_in_non_ignored_dir.txt"
        end
        model.upload(path, check_resources)
      end

      it "includes hidden files (though stager ignores them currently)" do
        mock_zip do |src, _|
          expect(relative_glob(src)).to include ".hidden_file"
        end
        model.upload(path, check_resources)
      end

      it "does not include files and directories specified in the cfignore" do
        mock_zip do |src, _|
          files = relative_glob(src)
          expect(files).to match_array(%w[
          .hidden_file .cfignore non_ignored_dir ambiguous_ignored
          non_ignored_dir/file_in_non_ignored_dir.txt non_ignored_file.txt
          non_ignored_dir/toplevel_ignored.txt
        ])
        end
        model.upload(path, check_resources)
      end

      %w(.git _darcs .svn).each do |source_control_dir_name|
        context "when there is a #{source_control_dir_name} directory in the app" do
          before { FileUtils.mkdir_p("#{path}/#{source_control_dir_name}") }

          it "ignores that directory" do
            mock_zip do |src, _|
              expect(relative_glob(src)).not_to include source_control_dir_name
            end
            model.upload(path, check_resources)
          end
        end
      end

      context "when there are no files to zip" do
        before { mock_zip { false } }

        it "passes `false` to #upload_app" do
          base.should_receive(:upload_app).with(guid, false, [])
          model.upload(path, check_resources)
        end
      end

      context "when all files match existing resources" do
        context "and there are directories" do
          let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_nested_directories" }

          it "prunes them before zipping" do
            model.stub(:make_fingerprints).with(anything) do
              [[], CFoundry::UploadHelpers::RESOURCE_CHECK_LIMIT + 1]
            end

            base.stub(:resource_match).with(anything) do
              %w{ xyz foo/bar/baz/fizz }.map do |path|
                {:fn => "#{tmpdir}/.cf_#{guid}_files/#{path}"}
              end
            end

            base.should_receive(:upload_app).with(anything, false, anything)
            model.upload(path)
          end
        end
      end

      context "when only dotfiles don't match existing resources" do
        let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_dotfiles" }

        it "does not prune them" do
          model.stub(:make_fingerprints).with(anything) do
            [[], CFoundry::UploadHelpers::RESOURCE_CHECK_LIMIT + 1]
          end

          base.stub(:resource_match).with(anything) do
            %w{ xyz }.map do |path|
              {:fn => "#{tmpdir}/.cf_#{guid}_files/#{path}"}
            end
          end

          base.should_receive(:upload_app).with(anything, anything, anything) do |_, zip, _|
            expect(zip).to be_a(String)
          end

          model.upload(path)
        end
      end

      context "when there is a symlink pointing outside of the root" do
        let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_external_symlink" }

        it "blows up" do
          expect {
            model.upload(path)
          }.to raise_error(CFoundry::Error, /contains links.*that point outside/)
        end

        context "and it is cfignored" do
          let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_ignored_external_symlink" }

          it "ignores it" do
            expect { model.upload(path) }.to_not raise_error
          end
        end
      end
    end
  end
end
