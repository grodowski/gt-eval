require_relative "test_helper"
require_relative "git_sandbox"

class SyncCommandTest < Minitest::Test
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

  def setup_stack_with_upstream_changes
    # Create branch A off main, push to remote
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "Commit on A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    # Simulate upstream: add a commit directly to remote's main
    # by working from the bare remote via another clone
    remote_clone = File.join(@tmpdir, "remote_clone")
    system("git", "clone", @remote, remote_clone, [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "user.email", "test@test.com",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "user.name", "Test",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "commit.gpgsign", "false",
           [:out, :err] => File::NULL)
    File.write(File.join(remote_clone, "upstream.txt"), "upstream\n")
    system("git", "-C", remote_clone, "add", "upstream.txt", [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "commit", "-m", "Upstream commit",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "push", "origin", "main",
           [:out, :err] => File::NULL)

    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)
  end

  def test_sync_pulls_main_and_restacks
    setup_stack_with_upstream_changes

    old_main_sha = GT::Git.tip_sha("main")
    GT::Commands::Sync.new([]).run

    new_main_sha = GT::Git.tip_sha("main")
    refute_equal old_main_sha, new_main_sha
    # feature-a should be rebased on top of new main
    assert_equal new_main_sha, GT::Git.gt_fork_point("feature-a")
  end

  def test_sync_returns_to_original_branch
    setup_stack_with_upstream_changes
    GT::Commands::Sync.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_sync_exits_when_no_gt_branches
    # No stacked branches — restack will exit 1
    e = assert_raises(SystemExit) { GT::Commands::Sync.new([]).run }
    assert_equal 1, e.status
  end

  def test_sync_exits_when_merge_fails
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")

    # Make a local commit on main that would prevent ff-only merge
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    make_commit("local.txt", "local", "Local commit on main")
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)

    # Advance remote main too
    remote_clone = File.join(@tmpdir, "remote_clone")
    system("git", "clone", @remote, remote_clone, [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "user.email", "test@test.com",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "user.name", "Test",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "config", "commit.gpgsign", "false",
           [:out, :err] => File::NULL)
    File.write(File.join(remote_clone, "remote.txt"), "remote\n")
    system("git", "-C", remote_clone, "add", "remote.txt", [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "commit", "-m", "Remote commit",
           [:out, :err] => File::NULL)
    system("git", "-C", remote_clone, "push", "origin", "main",
           [:out, :err] => File::NULL)

    e = assert_raises(SystemExit) { GT::Commands::Sync.new([]).run }
    assert_equal 1, e.status
  end

  def test_sync_fetch_failure_is_non_fatal
    # Remove remote to cause fetch failure
    system("git", "remote", "remove", "origin", [:out, :err] => File::NULL)

    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)

    # fetch fails (warning), then merge fails (no origin/main), then exit 1
    e = assert_raises(SystemExit) { GT::Commands::Sync.new([]).run }
    assert_equal 1, e.status
  end

  def test_sync_exits_when_checkout_main_fails
    fail_stat = mock_status(false)
    original  = GT::Git.method(:run)
    stub_run  = lambda do |*args|
      return ["", "could not checkout", fail_stat] if args == ["git", "checkout", "main"]
      original.call(*args)
    end
    with_stub(GT::Git, :run, stub_run) do
      make_gt_branch("feature-a", "main")
      make_commit("a.txt", "a", "A")
      e = assert_raises(SystemExit) { GT::Commands::Sync.new([]).run }
      assert_equal 1, e.status
    end
  end
end
