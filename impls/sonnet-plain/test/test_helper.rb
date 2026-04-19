# frozen_string_literal: true
require "simplecov"

# SimpleCov.formatter = SimpleCov::Formatter::HTML

SimpleCov.start do
  add_filter("/test/")
  enable_coverage(:branch)
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

require "gt"

# Disable cli-ui output routing in tests
CLI::UI::StdoutRouter.enable rescue nil

module GitSandbox
  # Sets up a bare remote and a local clone. Yields the local repo dir.
  def with_sandbox
    Dir.mktmpdir("gt-test-remote") do |remote_dir|
      Dir.mktmpdir("gt-test-local") do |local_dir|
        # Init bare remote
        git!(remote_dir, "git", "init", "--bare", "--initial-branch=main")

        # Clone into local
        git!(local_dir, "git", "clone", remote_dir, ".")
        git!(local_dir, "git", "config", "user.email", "test@test.com")
        git!(local_dir, "git", "config", "user.name", "Test User")

        # Make an initial commit on main so main exists
        File.write(File.join(local_dir, "README.md"), "hello\n")
        git!(local_dir, "git", "add", "README.md")
        git!(local_dir, "git", "commit", "-m", "Initial commit")
        git!(local_dir, "git", "push", "origin", "main")

        yield local_dir, remote_dir
      end
    end
  end

  def git!(dir, *args)
    stdout, stderr, status = Open3.capture3(*args, chdir: dir)
    unless status.success?
      raise "git command failed: #{args.join(" ")}\nstdout: #{stdout}\nstderr: #{stderr}"
    end
    stdout.strip
  end

  def gt(dir, *args)
    GT::App.new(args, dir: dir).run
  end

  def current_branch(dir)
    git!(dir, "git", "rev-parse", "--abbrev-ref", "HEAD")
  end

  def commit_sha(dir, ref = "HEAD")
    git!(dir, "git", "rev-parse", ref)
  end
end
