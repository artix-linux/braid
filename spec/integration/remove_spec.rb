require File.dirname(__FILE__) + '/integration_helper'

describe 'Removing a mirror' do
  before do
    FileUtils.rm_rf(TMP_PATH)
    FileUtils.mkdir_p(TMP_PATH)
  end

  describe 'braided directly in' do
    before do
      @repository_dir = create_git_repo_from_fixture('shiny')
      @vendor_repository_dir = create_git_repo_from_fixture('skit1')
      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} add #{@vendor_repository_dir}")

        # Next line ensure the remote still exists
        run_command("#{BRAID_BIN} setup skit1")
      end
    end

    it 'should remove the files and the remote' do

      assert_no_diff("#{FIXTURE_PATH}/skit1/layouts/layout.liquid", "#{@repository_dir}/skit1/layouts/layout.liquid")

      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} remove skit1")
      end

      expect(File.exist?("#{@repository_dir}/skit1)")).to eq(false)

      braids = YAML::load_file("#{@repository_dir}/.braids.json")
      expect(braids['skit1']).to be_nil

      expect(`#{BRAID_BIN} remote | grep skit1`).to eq('')
    end
  end

  describe 'braiding a subdirectory in' do
    before do
      @repository_dir = create_git_repo_from_fixture('shiny')
      @vendor_repository_dir = create_git_repo_from_fixture('skit1')
      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} add #{@vendor_repository_dir} --path layouts skit-layouts")
      end
    end

    it 'should remove the files and the remote' do

      assert_no_diff("#{FIXTURE_PATH}/skit1/layouts/layout.liquid", "#{@repository_dir}/skit-layouts/layout.liquid")

      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} remove skit-layouts")
      end

      expect(File.exist?("#{@repository_dir}/skit-layouts)")).to eq(false)

      braids = YAML::load_file("#{@repository_dir}/.braids.json")
      expect(braids['skit-layouts']).to be_nil
    end
  end

  # See the comment in adding_spec.rb regarding tests with paths containing
  # spaces.
  describe 'braiding a subdirectory in with paths containing spaces' do
    before do
      @repository_dir = create_git_repo_from_fixture('shiny', :directory => 'shiny with spaces')
      @vendor_repository_dir = create_git_repo_from_fixture('skit1_with_space', :directory => 'skit with spaces')
      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} add --path \"lay outs\" \"#{@vendor_repository_dir}\" \"skit lay outs\"")
      end
    end

    it 'should remove the files and the remote' do

      assert_no_diff("#{FIXTURE_PATH}/skit1_with_space/lay outs/layout.liquid", "#{@repository_dir}/skit lay outs/layout.liquid")

      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} remove \"skit lay outs\"")
      end

      expect(File.exist?("#{@repository_dir}/skit lay outs)")).to eq(false)

      braids = YAML::load_file("#{@repository_dir}/.braids.json")
      expect(braids['skit lay outs']).to be_nil
    end
  end

  describe 'braiding a single file in' do
    before do
      @repository_dir = create_git_repo_from_fixture('shiny')
      @vendor_repository_dir = create_git_repo_from_fixture('skit1')
      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} add #{@vendor_repository_dir} --path layouts/layout.liquid skit-layout.liquid")
      end
    end

    it 'should remove the files and the remote' do

      assert_no_diff("#{FIXTURE_PATH}/skit1/layouts/layout.liquid", "#{@repository_dir}/skit-layout.liquid")

      in_dir(@repository_dir) do
        run_command("#{BRAID_BIN} remove skit-layout.liquid")
      end

      expect(File.exist?("#{@repository_dir}/skit-layout.liquid)")).to eq(false)

      braids = YAML::load_file("#{@repository_dir}/.braids.json")
      expect(braids['skit-layout.liquid']).to be_nil
    end
  end
end
