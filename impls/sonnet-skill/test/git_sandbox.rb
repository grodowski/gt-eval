require "tmpdir"
require "fileutils"

# Mixin for Minitest tests that need an isolated git repo with a bare remote.
# Include this module and call super in setup/teardown.
#
# Provides:
#   @workdir  - path to the working repository
#   @remote   - path to the bare remote repository
#
# All git operations inside tests should be performed inside @workdir.
module GitSandbox
  LOCAL_GIT_CONFIG = {
    "user.email"     => "test@test.com",
    "user.name"      => "Test User",
    "commit.gpgsign" => "false",
  }.freeze

  def setup
    @orig_dir = Dir.pwd
    @tmpdir   = Dir.mktmpdir("gt-test-")

    # Create a bare remote repo
    @remote = File.join(@tmpdir, "remote.git")
    Dir.mkdir(@remote)
    system("git", "init", "--bare", "--initial-branch=main", @remote,
           exception: true, [:out, :err] => File::NULL)

    # Create a working repo
    @workdir = File.join(@tmpdir, "repo")
    Dir.mkdir(@workdir)
    Dir.chdir(@workdir)

    system("git", "init", "--initial-branch=main", exception: true, [:out, :err] => File::NULL)
    system("git", "remote", "add", "origin", @remote, exception: true, [:out, :err] => File::NULL)

    LOCAL_GIT_CONFIG.each do |key, val|
      system("git", "config", key, val, exception: true, [:out, :err] => File::NULL)
    end

    # Initial commit on main
    File.write(File.join(@workdir, "README.md"), "# Test repo\n")
    system("git", "add", ".", exception: true, [:out, :err] => File::NULL)
    system("git", "commit", "-m", "Initial commit", exception: true, [:out, :err] => File::NULL)
    system("git", "push", "-u", "origin", "main", exception: true, [:out, :err] => File::NULL)

    super
  end

  def teardown
    Dir.chdir(@orig_dir)
    FileUtils.rm_rf(@tmpdir)
    super
  end

  # Helper: write a file, git add, git commit
  def make_commit(filename, content, message)
    File.write(File.join(@workdir, filename), content)
    system("git", "add", filename, exception: true, [:out, :err] => File::NULL)
    system("git", "commit", "-m", message, exception: true, [:out, :err] => File::NULL)
  end

  # Helper: create and checkout a branch, set gt config
  def make_gt_branch(name, parent)
    fork_point = `git rev-parse #{parent}`.strip
    system("git", "checkout", "-b", name, exception: true, [:out, :err] => File::NULL)
    system("git", "config", "branch.#{name}.gt-parent", parent, exception: true, [:out, :err] => File::NULL)
    system("git", "config", "branch.#{name}.gt-fork-point", fork_point, exception: true, [:out, :err] => File::NULL)
    fork_point
  end
end
