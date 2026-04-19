# frozen_string_literal: true
require "simplecov"

# SimpleCov.formatter = SimpleCov::Formatter::HTML

SimpleCov.start do
  add_filter("/test/")
  enable_coverage(:branch)
end

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/gt"

# Helper that creates a tmpdir with a bare remote and a local clone per test.
module GitSandbox
  def setup
    @sandbox_dir = Dir.mktmpdir("gt-test-")

    # Create bare remote
    @remote_dir = File.join(@sandbox_dir, "remote.git")
    FileUtils.mkdir_p(@remote_dir)
    system("git", "init", "--bare", "--initial-branch=main", @remote_dir, out: File::NULL, err: File::NULL)

    # Create local clone
    @local_dir = File.join(@sandbox_dir, "local")
    system("git", "clone", @remote_dir, @local_dir, out: File::NULL, err: File::NULL)

    Dir.chdir(@local_dir)

    # Ensure we're on a branch called main
    system("git", "checkout", "-B", "main", out: File::NULL, err: File::NULL)

    # Configure git user for commits
    system("git", "config", "user.email", "test@test.com", out: File::NULL, err: File::NULL)
    system("git", "config", "user.name", "Test", out: File::NULL, err: File::NULL)

    # Create initial commit on main
    File.write("README.md", "# test\n")
    system("git", "add", "README.md", out: File::NULL, err: File::NULL)
    system("git", "commit", "-m", "initial commit", out: File::NULL, err: File::NULL)
    system("git", "push", "-u", "origin", "main", out: File::NULL, err: File::NULL)

    super
  end

  def teardown
    super
    Dir.chdir("/")
    FileUtils.rm_rf(@sandbox_dir) if @sandbox_dir && File.exist?(@sandbox_dir)
  end

  # Helper: create a file, stage, and commit
  def make_commit(filename = "file.txt", content: "content\n", message: "commit")
    File.write(filename, content)
    system("git", "add", filename, out: File::NULL, err: File::NULL)
    system("git", "commit", "-m", message, out: File::NULL, err: File::NULL)
  end

  # Helper: set up a gt-managed branch
  def create_gt_branch(name, parent:)
    GT::Git.run("checkout", "-b", name)
    GT::Git.set_gt_parent(name, parent)
    GT::Git.set_gt_fork_point(name, GT::Git.rev_parse(parent))
  end
end
