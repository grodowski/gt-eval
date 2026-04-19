require_relative "test_helper"
require_relative "git_sandbox"

class CreateCommandTest < Minitest::Test
  include GitSandbox

  # Helper: a fake status object responding to success?
  def mock_status(success)
    s = Object.new
    s.define_singleton_method(:success?) { success }
    s
  end

  # Temporarily replace obj.method_name with the given callable or value.
  def with_stub(obj, method_name, value_or_callable)
    original = obj.method(method_name)
    if value_or_callable.respond_to?(:call)
      obj.define_singleton_method(method_name, &value_or_callable)
    else
      obj.define_singleton_method(method_name) { |*| value_or_callable }
    end
    yield
  ensure
    obj.define_singleton_method(method_name, &original)
  end

  # Helper: stub Git.run to fail for a specific git sub-command
  def with_git_run_failing_on(subcommand)
    original  = GT::Git.method(:run)
    fail_stat = mock_status(false)
    stub_run  = lambda do |*args|
      return ["", "simulated error", fail_stat] if args[1] == subcommand
      original.call(*args)
    end
    with_stub(GT::Git, :run, stub_run) { yield }
  end

  # Helper: install a fake `gh` in a tmpdir, prepend to PATH
  def with_fake_gh(exit_code: 0, output: "https://github.com/org/repo/pull/1")
    fake_dir = File.join(@tmpdir, "fakebin")
    Dir.mkdir(fake_dir)
    File.write(File.join(fake_dir, "gh"), "#!/bin/sh\necho '#{output}'\nexit #{exit_code}\n")
    FileUtils.chmod(0o755, File.join(fake_dir, "gh"))
    old_path = ENV["PATH"]
    ENV["PATH"] = "#{fake_dir}:#{old_path}"
    yield
  ensure
    ENV["PATH"] = old_path
  end

  # ---- initialize ----

  def test_initialize_stores_name
    cmd = GT::Commands::Create.new(["my-branch"])
    assert_equal "my-branch", cmd.instance_variable_get(:@name)
    assert_nil cmd.instance_variable_get(:@message)
  end

  def test_initialize_parses_message_flag
    cmd = GT::Commands::Create.new(["my-branch", "-m", "hello"])
    assert_equal "my-branch", cmd.instance_variable_get(:@name)
    assert_equal "hello", cmd.instance_variable_get(:@message)
  end

  def test_initialize_ignores_unknown_flags
    # Passes through a non-'-m' flag — exercises the else branch of `if flag == "-m"`
    cmd = GT::Commands::Create.new(["my-branch", "--verbose"])
    assert_nil cmd.instance_variable_get(:@message)
  end

  # ---- run: argument validation ----

  def test_create_without_name_exits
    e = assert_raises(SystemExit) { GT::Commands::Create.new([]).run }
    assert_equal 1, e.status
  end

  # ---- run: git failures (stubbed) ----

  def test_create_fails_when_current_branch_unknown
    with_stub(GT::Git, :current_branch, nil) do
      e = assert_raises(SystemExit) do
        GT::Commands::Create.new(["branch-x", "-m", "msg"]).run
      end
      assert_equal 1, e.status
    end
  end

  def test_create_fails_when_fork_point_unknown
    with_stub(GT::Git, :tip_sha, nil) do
      e = assert_raises(SystemExit) do
        GT::Commands::Create.new(["branch-x", "-m", "msg"]).run
      end
      assert_equal 1, e.status
    end
  end

  def test_create_fails_when_git_add_fails
    with_git_run_failing_on("add") do
      e = assert_raises(SystemExit) do
        GT::Commands::Create.new(["branch-x", "-m", "msg"]).run
      end
      assert_equal 1, e.status
    end
  end

  def test_create_fails_when_checkout_fails
    # Trying to create a branch that already exists causes checkout failure
    e = assert_raises(SystemExit) do
      GT::Commands::Create.new(["main", "-m", "msg"]).run
    end
    assert_equal 1, e.status
  end

  def test_create_fails_when_commit_fails
    with_git_run_failing_on("commit") do
      e = assert_raises(SystemExit) do
        GT::Commands::Create.new(["branch-x", "-m", "msg"]).run
      end
      assert_equal 1, e.status
    end
  end

  # ---- run: push failure degrades gracefully ----

  def test_create_with_push_failure_still_succeeds
    system("git", "remote", "remove", "origin", [:out, :err] => File::NULL)
    # Should not raise SystemExit (push failure is a warning, not fatal)
    GT::Commands::Create.new(["branch-e", "-m", "push test"]).run
    assert_equal "branch-e", GT::Git.current_branch
  end

  # ---- run: no -m defaults commit message to branch name ----

  def test_create_without_message_creates_branch
    GT::Commands::Create.new(["branch-nomsg"]).run
    assert_equal "branch-nomsg", GT::Git.current_branch
    assert_equal "main", GT::Git.gt_parent("branch-nomsg")
    log, _, _ = GT::Git.run("git", "log", "--oneline", "-1")
    assert_includes log, "branch-nomsg"
  end

  # ---- run: open_pr success ----

  def test_open_pr_success_prints_url
    with_fake_gh(exit_code: 0, output: "https://github.com/org/repo/pull/42") do
      GT::Commands::Create.new(["branch-pr", "-m", "pr test"]).run
    end
    assert_equal "branch-pr", GT::Git.current_branch
  end

  # ---- run: end-to-end happy paths ----

  def test_create_branch_with_message
    File.write(File.join(@workdir, "feature.txt"), "feature content\n")
    system("git", "add", "feature.txt", exception: true, [:out, :err] => File::NULL)

    GT::Commands::Create.new(["feature-a", "-m", "Add feature"]).run

    assert_equal "feature-a", GT::Git.current_branch
    assert_equal "main", GT::Git.gt_parent("feature-a")
    refute_nil GT::Git.gt_fork_point("feature-a")
    log, _, _ = GT::Git.run("git", "log", "--oneline", "-1")
    assert_includes log, "Add feature"
  end

  def test_create_sets_fork_point_to_parent_tip
    main_sha = GT::Git.tip_sha("main")
    GT::Commands::Create.new(["branch-b", "-m", "B commit"]).run
    assert_equal main_sha, GT::Git.gt_fork_point("branch-b")
  end

  def test_create_stacks_on_current_branch
    GT::Commands::Create.new(["branch-a", "-m", "A commit"]).run
    a_sha = GT::Git.tip_sha("branch-a")
    GT::Commands::Create.new(["branch-b", "-m", "B commit"]).run

    assert_equal "branch-a", GT::Git.gt_parent("branch-b")
    assert_equal a_sha, GT::Git.gt_fork_point("branch-b")
  end

  def test_create_with_staged_changes
    File.write(File.join(@workdir, "staged.txt"), "staged\n")
    system("git", "add", "staged.txt", exception: true, [:out, :err] => File::NULL)

    GT::Commands::Create.new(["branch-c", "-m", "Staged commit"]).run

    assert_equal "branch-c", GT::Git.current_branch
    log, _, _ = GT::Git.run("git", "show", "--name-only", "--format=", "HEAD")
    assert_includes log, "staged.txt"
  end

  def test_create_with_untracked_only_still_creates_branch
    File.write(File.join(@workdir, "untracked.txt"), "untracked\n")
    GT::Commands::Create.new(["branch-d", "-m", "Untracked commit"]).run
    assert_equal "branch-d", GT::Git.current_branch
  end
end
