# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/restack"

class RestackTest < Minitest::Test
  include GitSandbox

  def test_restack_no_managed_branches_exits
    assert_raises(SystemExit) do
      GT::Commands::Restack.new([]).run
    end
  end

  def test_restack_already_up_to_date
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    assert_equal "branch-a", GT::Git.current_branch
  end

  def test_restack_after_parent_change
    # Create stack: main -> branch-a -> branch-b
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    # Go back to branch-a and add a new commit (simulating parent advancing)
    GT::Git.run("checkout", "branch-a")
    make_commit("d.txt", message: "new on a")

    # Restack from branch-a
    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    # branch-b should now include the new commit from branch-a
    GT::Git.run("checkout", "branch-b")
    log = GT::Git.run("log", "--oneline")
    assert_includes log, "new on a"
    assert_includes log, "on b"
  end

  def test_restack_from_any_branch_restacks_whole_stack
    # Create stack: main -> a -> b -> c
    make_commit("a.txt", message: "base change")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    create_gt_branch("branch-c", parent: "branch-b")
    make_commit("d.txt", message: "on c")

    # Advance branch-a
    GT::Git.run("checkout", "branch-a")
    make_commit("e.txt", message: "new on a")

    # Restack from branch-c (should restack whole stack)
    GT::Git.run("checkout", "branch-c")
    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    # branch-c should have the new commit
    GT::Git.run("checkout", "branch-c")
    log = GT::Git.run("log", "--oneline")
    assert_includes log, "new on a"
  end

  def test_restack_updates_fork_points
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    old_fork = GT::Git.gt_fork_point("branch-a")

    # Advance main
    GT::Git.run("checkout", "main")
    make_commit("x.txt", message: "advance main")
    new_main_sha = GT::Git.rev_parse("main")

    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    # Fork point should be updated to new main tip
    assert_equal new_main_sha, GT::Git.gt_fork_point("branch-a")
    refute_equal old_fork, GT::Git.gt_fork_point("branch-a")
  end

  def test_restack_force_pushes
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")
    GT::Git.run("push", "-u", "origin", "branch-a")

    # Advance main
    GT::Git.run("checkout", "main")
    make_commit("x.txt", message: "advance main")

    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    # Should still be on branch-a (it was in the stack)
    # and the remote should have the rebased commit
    GT::Git.run("checkout", "branch-a")
    local_sha = GT::Git.rev_parse("HEAD")
    remote_sha = GT::Git.rev_parse("origin/branch-a")
    assert_equal local_sha, remote_sha
  end

  def test_restack_returns_to_original_branch
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    GT::Git.run("checkout", "branch-a")

    GT::GH.stub(:available?, false) do
      GT::Commands::Restack.new([]).run
    end

    assert_equal "branch-a", GT::Git.current_branch
  end
end
