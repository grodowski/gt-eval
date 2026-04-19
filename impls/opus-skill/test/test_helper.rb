require "simplecov"
require "undercover/simplecov_formatter"

SimpleCov.formatter = SimpleCov::Formatter::Undercover

SimpleCov.start do
  add_filter("/test/")
  add_filter("Rakefile")
  enable_coverage(:branch)
end

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/gt"

class GitSandbox
  attr_reader :repo_dir, :remote_dir

  def initialize
    @base_dir = Dir.mktmpdir("gt-test-")
    @remote_dir = File.join(@base_dir, "remote.git")
    @repo_dir = File.join(@base_dir, "repo")

    # Create bare remote with main as default branch
    run_git_in(nil, "init", "--bare", "--initial-branch=main", @remote_dir)

    # Clone it to create the working repo
    run_git_in(nil, "clone", @remote_dir, @repo_dir)

    # Create initial commit on main
    Dir.chdir(@repo_dir) do
      run_git_in(@repo_dir, "checkout", "-b", "main")
      File.write("README.md", "# test\n")
      run_git("add", "README.md")
      run_git("commit", "-m", "Initial commit")
      run_git("push", "-u", "origin", "main")
    end
  end

  def run_git(*args)
    run_git_in(@repo_dir, *args)
  end

  def run_git_in(dir, *args)
    opts = dir ? { chdir: dir } : {}
    out, err, status = Open3.capture3("git", *args, **opts)
    unless status.success?
      raise "git #{args.join(' ')} failed in #{dir}: #{err}"
    end

    out.chomp
  end

  def cleanup
    FileUtils.rm_rf(@base_dir)
  end

  def chdir(&block)
    Dir.chdir(@repo_dir, &block)
  end
end

class GTTest < Minitest::Test
  def setup
    @sandbox = GitSandbox.new
    @original_dir = Dir.pwd
    Dir.chdir(@sandbox.repo_dir)
  end

  def teardown
    Dir.chdir(@original_dir)
    @sandbox.cleanup
  end

  private

  def sandbox
    @sandbox
  end

  def run_gt(*args)
    GT::CLI.run(args.dup)
  end
end
