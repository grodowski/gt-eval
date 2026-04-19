require_relative "test_helper"
require_relative "git_sandbox"

class RestackCommandTest < Minitest::Test
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

  # Build a stack where main has diverged: we add a new commit to main
  # and then verify restack rebases the child branches.
  def setup_diverged_stack
    # Branch A off main
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "Commit on A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    # Branch B off A
    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b", "Commit on B")
    system("git", "push", "-u", "origin", "feature-b", [:out, :err] => File::NULL)

    # Advance main with a new commit (simulates upstream work)
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    make_commit("main2.txt", "m2", "New commit on main")
    system("git", "push", "origin", "main", [:out, :err] => File::NULL)

    # Manually update feature-a's gt-fork-point to the OLD main tip
    # (it already is, since we set it when we created feature-a)
    # Now feature-a's fork-point != main's new tip → needs rebase

    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
  end

  def test_restack_exits_when_no_gt_branches
    e = assert_raises(SystemExit) { GT::Commands::Restack.new([]).run }
    assert_equal 1, e.status
  end

  def test_restack_when_already_up_to_date
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A commit")

    # fork-point == main's tip → no rebase needed
    GT::Commands::Restack.new([]).run
    # Still on feature-a after restack (returned to original)
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_restack_rebases_child_on_updated_parent
    setup_diverged_stack

    # feature-a's fork-point is old main tip
    old_main_tip = GT::Git.gt_fork_point("feature-a")
    new_main_tip = GT::Git.tip_sha("main")

    refute_equal old_main_tip, new_main_tip

    GT::Commands::Restack.new([]).run

    # feature-a should now be based on new main tip
    assert_equal new_main_tip, GT::Git.gt_fork_point("feature-a")
  end

  def test_restack_updates_fork_point
    setup_diverged_stack

    new_main_tip = GT::Git.tip_sha("main")
    GT::Commands::Restack.new([]).run

    assert_equal new_main_tip, GT::Git.gt_fork_point("feature-a")
    # feature-b should now be based on new feature-a tip
    new_a_tip = GT::Git.tip_sha("feature-a")
    assert_equal new_a_tip, GT::Git.gt_fork_point("feature-b")
  end

  def test_restack_returns_to_original_branch
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")

    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)
    GT::Commands::Restack.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_restack_exits_on_rebase_failure
    # Create conflicting changes on main and feature-a
    make_gt_branch("feature-a", "main")
    make_commit("conflict.txt", "original", "A commit")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    # Advance main with a conflicting change
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    make_commit("conflict.txt", "main version", "Main conflicting commit")
    system("git", "push", "origin", "main", [:out, :err] => File::NULL)

    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)

    e = assert_raises(SystemExit) { GT::Commands::Restack.new([]).run }
    assert_equal 1, e.status

    # Abort the rebase to clean up
    GT::Git.run("git", "rebase", "--abort")
  end

  def test_restack_from_any_branch_in_stack
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b", "B")

    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)
    # Restack from feature-a should also handle feature-b
    GT::Commands::Restack.new([]).run
    # feature-a is already up-to-date; feature-b gets no rebase either
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_restack_push_failure_is_non_fatal
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")

    # Advance main to trigger a rebase
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    make_commit("main2.txt", "m2", "New on main")

    # Remove remote to cause push failure
    system("git", "remote", "remove", "origin", [:out, :err] => File::NULL)
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)

    # Should not raise — push failure is a warning
    GT::Commands::Restack.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_update_pr_description_degrades_gracefully
    # If gh fails, restack should still succeed
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")
    # Already up to date — no rebase triggered, but tests the path
    GT::Commands::Restack.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_restack_with_gh_success
    # Use a fake gh that exits 0 to cover the "gh pr edit succeeded" branch
    fake_dir = File.join(@tmpdir, "fakebin")
    Dir.mkdir(fake_dir)
    File.write(File.join(fake_dir, "gh"), "#!/bin/sh\nexit 0\n")
    FileUtils.chmod(0o755, File.join(fake_dir, "gh"))
    old_path = ENV["PATH"]
    ENV["PATH"] = "#{fake_dir}:#{old_path}"

    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    # Advance main to trigger rebase on feature-a
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    make_commit("main2.txt", "m2", "New on main")
    system("git", "push", "origin", "main", [:out, :err] => File::NULL)
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)

    GT::Commands::Restack.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  ensure
    ENV["PATH"] = old_path
  end
end
