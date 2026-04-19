require_relative "test_helper"
require_relative "git_sandbox"

class ModifyCommandTest < Minitest::Test
  include GitSandbox

  def mock_status(success)
    s = Object.new
    s.define_singleton_method(:success?) { success }
    s
  end

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

  def setup
    super
    # Build a 2-branch stack: feature-a → feature-b
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "original a", "Original A commit")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b content", "B commit")
    system("git", "push", "-u", "origin", "feature-b", [:out, :err] => File::NULL)

    # Go back to feature-a to modify it
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)
  end

  def test_modify_amends_head_commit
    # Stage a change so the amend produces a new tree and thus a new SHA
    File.write(File.join(@workdir, "a.txt"), "amended a\n")
    system("git", "add", "a.txt", exception: true, [:out, :err] => File::NULL)

    original_sha = GT::Git.tip_sha("feature-a")
    GT::Commands::Modify.new([]).run
    new_sha = GT::Git.tip_sha("feature-a")
    refute_equal original_sha, new_sha
  end

  def test_modify_with_message_updates_commit_message
    GT::Commands::Modify.new(["-m", "Updated message"]).run
    log, _, _ = GT::Git.run("git", "log", "--oneline", "-1", "feature-a")
    assert_includes log, "Updated message"
  end

  def test_modify_restacks_child_branches
    # Stage a change so amend produces a genuinely different SHA
    File.write(File.join(@workdir, "a.txt"), "amended a content\n")
    system("git", "add", "a.txt", exception: true, [:out, :err] => File::NULL)

    GT::Commands::Modify.new([]).run
    new_a_sha = GT::Git.tip_sha("feature-a")

    # feature-b should be rebased onto the new feature-a tip
    assert_equal new_a_sha, GT::Git.gt_fork_point("feature-b")
  end

  def test_modify_ends_at_stack_tip
    GT::Commands::Modify.new([]).run
    assert_equal "feature-b", GT::Git.current_branch
  end

  def test_modify_at_tip_stays_at_tip
    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
    GT::Commands::Modify.new([]).run
    assert_equal "feature-b", GT::Git.current_branch
  end

  def test_modify_exits_on_amend_failure
    fail_stat = mock_status(false)
    original  = GT::Git.method(:run)
    stub_run  = lambda do |*args|
      return ["", "amend failed", fail_stat] if args[1] == "commit" && args.include?("--amend")
      original.call(*args)
    end
    with_stub(GT::Git, :run, stub_run) do
      e = assert_raises(SystemExit) { GT::Commands::Modify.new([]).run }
      assert_equal 1, e.status
    end
  end

  def test_modify_push_failure_is_non_fatal
    system("git", "remote", "remove", "origin", [:out, :err] => File::NULL)
    # Should still succeed — push failure is a warning
    GT::Commands::Modify.new([]).run
    assert_equal "feature-b", GT::Git.current_branch
  end

  def test_modify_initializes_with_no_args
    cmd = GT::Commands::Modify.new([])
    assert_nil cmd.instance_variable_get(:@message)
  end

  def test_modify_initializes_with_message
    cmd = GT::Commands::Modify.new(["-m", "hello"])
    assert_equal "hello", cmd.instance_variable_get(:@message)
  end

  def test_modify_initializes_ignores_unknown_flags
    cmd = GT::Commands::Modify.new(["--verbose"])
    assert_nil cmd.instance_variable_get(:@message)
  end
end
