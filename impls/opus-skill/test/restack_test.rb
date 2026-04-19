# frozen_string_literal: true

require_relative "test_helper"

class RestackTest < GTTest
  def test_restack_no_gt_branches_exits_1
    err = assert_raises(SystemExit) { run_gt("restack") }
    assert_equal 1, err.status
  end

  def test_restack_updates_fork_points
    create_stack_with_push

    # Make a change on main that branch-a needs to rebase onto
    sandbox.run_git("checkout", "main")
    File.write("main_file.txt", "new main content")
    sandbox.run_git("add", "main_file.txt")
    sandbox.run_git("commit", "-m", "main change")
    sandbox.run_git("push", "origin", "main")

    new_main_tip = GT::Git.rev_parse("main")

    run_gt("restack")

    # fork point of branch-a should now be the new main tip
    assert_equal new_main_tip, GT::Git.fork_point_of("branch-a")
    # Should be on the tip
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_restack_from_any_branch
    create_stack_with_push

    sandbox.run_git("checkout", "main")
    File.write("main_file.txt", "new main content")
    sandbox.run_git("add", "main_file.txt")
    sandbox.run_git("commit", "-m", "main change")
    sandbox.run_git("push", "origin", "main")

    # Restack from branch-b (not main)
    sandbox.run_git("checkout", "branch-b")
    run_gt("restack")

    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_restack_noop_when_up_to_date
    create_stack_with_push

    # Restack when nothing has changed
    sandbox.run_git("checkout", "branch-a")
    run_gt("restack")

    # Should still work, end on tip
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_restack_preserves_commits
    create_stack_with_push

    sandbox.run_git("checkout", "main")
    File.write("main_file.txt", "new")
    sandbox.run_git("add", "main_file.txt")
    sandbox.run_git("commit", "-m", "main update")
    sandbox.run_git("push", "origin", "main")

    run_gt("restack")

    # branch-a should have main_file.txt (from main) and its own changes
    sandbox.run_git("checkout", "branch-a")
    assert File.exist?("main_file.txt")
    assert_equal "v2", File.read("file.txt")
  end

  def test_restack_from_main_with_gt_branches
    create_stack_with_push
    sandbox.run_git("checkout", "main")
    run_gt("restack")
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_build_stack_comment
    require_relative "../lib/gt/commands/restack"
    comment = GT::Commands::Restack.build_stack_comment(["a", "b", "c"], "main")
    assert_match(/main.*base/, comment)
    assert_match(/`a`/, comment)
    assert_match(/`b`/, comment)
    assert_match(/`c`/, comment)
  end

  def test_restack_branch_with_no_parent
    require_relative "../lib/gt/commands/restack"
    # Calling restack_branch on a branch with no gt-parent should return nil
    result = GT::Commands::Restack.restack_branch("main")
    assert_nil result
  end

  def test_restack_with_push_failure
    create_stack_with_push
    sandbox.run_git("checkout", "main")
    File.write("main_file.txt", "new")
    sandbox.run_git("add", "main_file.txt")
    sandbox.run_git("commit", "-m", "main update")

    # Remove remote so push fails
    sandbox.run_git("remote", "remove", "origin")

    run_gt("restack")

    # Should still complete despite push failures
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_update_pr_descriptions_without_gh
    require_relative "../lib/gt/commands/restack"
    old_path = ENV["PATH"]
    ENV["PATH"] = ""
    # Should return nil when gh is not available
    result = GT::Commands::Restack.update_pr_descriptions(["branch-a"])
    assert_nil result
  ensure
    ENV["PATH"] = old_path
  end

  private

  def create_stack_with_push
    File.write("file.txt", "v1")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    sandbox.run_git("checkout", "-b", "branch-a")
    GT::Git.set_parent("branch-a", "main")
    GT::Git.set_fork_point("branch-a", GT::Git.rev_parse("main"))
    File.write("file.txt", "v2")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch a change")
    sandbox.run_git("push", "-u", "origin", "branch-a")

    sandbox.run_git("checkout", "-b", "branch-b")
    GT::Git.set_parent("branch-b", "branch-a")
    GT::Git.set_fork_point("branch-b", GT::Git.rev_parse("branch-a"))
    File.write("file.txt", "v3")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch b change")
    sandbox.run_git("push", "-u", "origin", "branch-b")
  end
end
