require 'rubygems/installer_test_case'
require 'rubygems/commands/uninstall_command'

class TestGemCommandsUninstallCommand < Gem::InstallerTestCase

  def setup
    super

    build_rake_in do
      use_ui @ui do
        @installer.install
      end
    end

    @cmd = Gem::Commands::UninstallCommand.new
    @executable = File.join(@gemhome, 'bin', 'executable')
  end

  def test_execute_all_gem_names
    @cmd.options[:args] = %w[a b]
    @cmd.options[:all] = true

    assert_raises Gem::MockGemUi::TermError do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_match(/\A(?:WARNING:  Unable to use symlinks on Windows, installing wrapper\n)?ERROR:  Gem names and --all may not be used together\n\z/,
                 @ui.error)
  end

  def test_execute_dependency_order
    c = quick_gem 'c' do |spec|
      spec.add_dependency 'a'
    end

    util_build_gem c
    installer = util_installer c, @gemhome
    use_ui @ui do installer.install end

    ui = Gem::MockGemUi.new

    @cmd.options[:args] = %w[a c]
    @cmd.options[:executables] = true

    use_ui ui do
      @cmd.execute
    end

    output = ui.output.split "\n"

    assert_equal 'Successfully uninstalled c-2', output.shift
    assert_equal "Removing executable",          output.shift
    assert_equal 'Successfully uninstalled a-2', output.shift
  end

  def test_execute_removes_executable
    ui = Gem::MockGemUi.new

    util_setup_gem ui

    build_rake_in do
      use_ui ui do
        @installer.install
      end
    end

    if win_platform? then
      assert File.exist?(@executable)
    else
      assert File.symlink?(@executable)
    end

    # Evil hack to prevent false removal success
    FileUtils.rm_f @executable

    open @executable, "wb+" do |f| f.puts "binary" end

    @cmd.options[:executables] = true
    @cmd.options[:args] = [@spec.name]
    use_ui @ui do
      @cmd.execute
    end

    output = @ui.output.split "\n"
    assert_match(/Removing executable/, output.shift)
    assert_match(/Successfully uninstalled/, output.shift)
    assert_equal false, File.exist?(@executable)
    assert_nil output.shift, "UI output should have contained only two lines"
  end

  def test_execute_removes_formatted_executable
    FileUtils.rm_f @executable # Wish this didn't happen in #setup

    Gem::Installer.exec_format = 'foo-%s-bar'

    @installer.format_executable = true
    @installer.install

    formatted_executable = File.join @gemhome, 'bin', 'foo-executable-bar'
    assert_equal true, File.exist?(formatted_executable)

    @cmd.options[:executables] = true
    @cmd.options[:format_executable] = true
    @cmd.execute

    assert_equal false, File.exist?(formatted_executable)
  rescue
    Gem::Installer.exec_format = nil
  end

  def test_execute_prerelease
    @spec = quick_spec "pre", "2.b"
    @gem = File.join @tempdir, @spec.file_name
    FileUtils.touch @gem

    util_setup_gem

    build_rake_in do
      use_ui @ui do
        @installer.install
      end
    end

    @cmd.options[:executables] = true
    @cmd.options[:args] = ["pre"]

    use_ui @ui do
      @cmd.execute
    end

    output = @ui.output
    assert_match(/Successfully uninstalled/, output)
  end

  def test_execute_with_force_leaves_executable
    ui = Gem::MockGemUi.new

    util_make_gems
    util_setup_gem ui

    @cmd.options[:version] = '1'
    @cmd.options[:force] = true
    @cmd.options[:args] = ['a']

    use_ui ui do
      @cmd.execute
    end

    assert !Gem::Specification.all_names.include?('a')
    assert File.exist? File.join(@gemhome, 'bin', 'executable')
  end

  def test_execute_with_force_uninstalls_all_versions
    ui = Gem::MockGemUi.new "y\n"

    util_make_gems
    util_setup_gem ui

    assert Gem::Specification.find_all_by_name('a').length > 1

    @cmd.options[:force] = true
    @cmd.options[:args] = ['a']

    use_ui ui do
      @cmd.execute
    end

    refute_includes Gem::Specification.all_names, 'a'
  end

  def test_execute_with_force_ignores_dependencies
    ui = Gem::MockGemUi.new

    util_make_gems
    util_setup_gem ui

    assert Gem::Specification.find_all_by_name('dep_x').length > 0
    assert Gem::Specification.find_all_by_name('x').length > 0

    @cmd.options[:force] = true
    @cmd.options[:args] = ['x']

    use_ui ui do
      @cmd.execute
    end

    assert Gem::Specification.find_all_by_name('dep_x').length > 0
    assert Gem::Specification.find_all_by_name('x').length == 0
  end

  def test_execute_all
    ui = Gem::MockGemUi.new "y\n"

    util_make_gems
    util_setup_gem ui

    assert Gem::Specification.find_all_by_name('a').length > 1

    @cmd.options[:all] = true
    @cmd.options[:args] = []

    use_ui ui do
      @cmd.execute
    end

    refute_includes Gem::Specification.all_names, 'a'
  end

end

