require "spec_helper"

describe CFoundry::UploadHelpers do
  describe '#upload' do
    let(:base) { Object.new }
    let(:guid) { "123" }
    let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_vmcignore" }
    let(:check_resources) { false }
    let(:tmpdir) { "#{SPEC_ROOT}/tmp/fake_tmpdir" }

    let(:client) do
      client = Object.new
      stub(client).base { base }
      client
    end

    let(:fake_model) do
      class FakeModel
        include CFoundry::UploadHelpers

        def initialize(client, guid)
          @client = client
          @guid = guid
        end
      end

      FakeModel.new(client, guid)
    end

    before do
      FileUtils.rm_rf tmpdir

      stub(Dir).tmpdir do
        FileUtils.mkdir_p tmpdir
        tmpdir
      end

      stub(base).upload_app.with_any_args
    end

    subject { fake_model.upload(path, check_resources) }

    def relative_glob(dir)
      base_pathname = Pathname.new(dir)
      Dir["#{dir}/**/{*,.[^\.]*}"].map do |file|
        Pathname.new(file).relative_path_from(base_pathname).to_s
      end
    end

    def mock_zip(*args, &block)
      if args.empty?
        mock(CFoundry::Zip).pack.with_any_args(&block)
      else
        mock(CFoundry::Zip).pack(*args, &block)
      end
    end

    it 'zips the app and uploads the zip file' do
      zip_path = "#{tmpdir}/#{guid}.zip"
      mock_zip(anything, zip_path) { true }
      mock(base).upload_app(guid, zip_path, [])
      subject
    end

    it 'uploads an app with the right guid' do
      mock_zip
      mock(base).upload_app(guid, anything, anything)
      subject
    end

    it 'uses a unique directory name when it copies the app' do
      mock_zip(/#{tmpdir}.*#{guid}.*/, anything)
      subject
    end

    it 'cleans up after itself correctly' do
      subject
      expect(relative_glob(tmpdir)).to be_empty
    end

    it 'includes the source files of the app in the zip file' do
      mock_zip do |src, _|
        files = relative_glob(src)
        expect(files).to include "non_ignored_dir"
        expect(files).to include "non_ignored_file.txt"
        expect(files).to include "non_ignored_dir/file_in_non_ignored_dir.txt"
      end
      subject
    end

    it 'includes hidden files (though stager ignores them currently)' do
      mock_zip do |src, _|
        expect(relative_glob(src)).to include ".hidden_file"
      end
      subject
    end

    it 'does not include files and directories specified in the vmcignore' do
      mock_zip do |src, _|
        files = relative_glob(src)
        expect(files).to match_array(%w[
          .hidden_file .vmcignore non_ignored_dir ambiguous_ignored
          non_ignored_dir/file_in_non_ignored_dir.txt non_ignored_file.txt
          non_ignored_dir/toplevel_ignored.txt
        ])
      end
      subject
    end

    %w(.git _darcs .svn).each do |source_control_dir_name|
      context "when there is a #{source_control_dir_name} directory in the app" do
        before { FileUtils.mkdir_p("#{path}/#{source_control_dir_name}") }

        it "ignores that directory" do
          mock_zip do |src, _|
            expect(relative_glob(src)).not_to include source_control_dir_name
          end
          subject
        end
      end
    end

    context 'when there are no files to zip' do
      before { mock_zip { false } }

      it 'passes `false` to #upload_app' do
        mock(base).upload_app(guid, false, [])
        subject
      end
    end

    context 'when all files match existing resources' do
      context 'and there are directories' do
        let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_nested_directories" }

        it 'prunes them before zipping' do
          stub(fake_model).make_fingerprints(anything) do
            [[], CFoundry::UploadHelpers::RESOURCE_CHECK_LIMIT + 1]
          end

          stub(base).resource_match(anything) do
            %w{ xyz foo/bar/baz/fizz }.map do |path|
              { :fn => "#{tmpdir}/.vmc_#{guid}_files/#{path}" }
            end
          end

          mock(base).upload_app(anything, false, anything)

          fake_model.upload(path)
        end
      end
    end

    context "when only dotfiles don't match existing resources" do
      let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_dotfiles" }

      it 'does not prune them' do
        stub(fake_model).make_fingerprints(anything) do
          [[], CFoundry::UploadHelpers::RESOURCE_CHECK_LIMIT + 1]
        end

        stub(base).resource_match(anything) do
          %w{ xyz }.map do |path|
            { :fn => "#{tmpdir}/.vmc_#{guid}_files/#{path}" }
          end
        end

        mock(base).upload_app(anything, anything, anything) do |_, zip, _|
          expect(zip).to be_a(String)
        end

        fake_model.upload(path)
      end
    end

    context "when there is a symlink pointing outside of the root" do
      let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_external_symlink" }

      it "blows up" do
        expect {
          fake_model.upload(path)
        }.to raise_error(CFoundry::Error, /contains links.*that point outside/)
      end

      context "and it is vmcignored" do
        let(:path) { "#{SPEC_ROOT}/fixtures/apps/with_ignored_external_symlink" }

        it "ignores it" do
          expect { fake_model.upload(path) }.to_not raise_error
        end
      end
    end
  end
end
