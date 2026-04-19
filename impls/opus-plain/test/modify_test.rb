# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/modify"

class ModifyTest < Minitest::Test
  include GitSandbox

  def test_modify_amends_and_restacks
    # Build stack: main -> branch-a -> branch-b
    create_gt_branch("branch-a", parent: "main")
    make_commit("a.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("b.txt", message: "on b")

    # Go to branch-a and modify
    GT::Git.run("checkout", "branch-a")
    File.write("a.txt", "amended content\n")

    GT::GH.stub(:available?, false) do
      GT::Commands::Modify.new([]).run
    end

    # Should end on tip (branch-b)
    assert_equal "branch-b", GT::Git.current_branch

    # branch-a should have the amended content
    GT::Git.run("checkout", "branch-a")
    assert_equal "amended content\n", File.read("a.txt")

    # branch-b should also have the amended content (restacked)
    GT::Git.run("checkout", "branch-b")
    assert_equal "amended content\n", File.read("a.txt")
  end

  def test_modify_ends_on_tip
    create_gt_branch("branch-a", parent: "main")
    make_commit("a.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("b.txt", message: "on b")

    create_gt_branch("branch-c", parent: "branch-b")
    make_commit("c.txt", message: "on c")

    # Modify from branch-a
    GT::Git.run("checkout", "branch-a")
    File.write("a.txt", "modified\n")

    GT::GH.stub(:available?, false) do
      GT::Commands::Modify.new([]).run
    end

    # Should be on the tip
    assert_equal "branch-c", GT::Git.current_branch
  end

  def test_modify_on_unmanaged_branch_exits
    GT::Git.run("checkout", "-b", "random-branch")
    make_commit("x.txt", message: "random")

    assert_raises(SystemExit) do
      GT::Commands::Modify.new([]).run
    end
  end

  def test_modify_with_no_changes_still_amends
    create_gt_branch("branch-a", parent: "main")
    make_commit("a.txt", message: "on a")

    # No changes — amend should still work (no-op amend)
    GT::GH.stub(:available?, false) do
      GT::Commands::Modify.new([]).run
    end

    assert_equal "branch-a", GT::Git.current_branch
  end

  def test_modify_force_pushes
    create_gt_branch("branch-a", parent: "main")
    make_commit("a.txt", message: "on a")
    GT::Git.run("push", "-u", "origin", "branch-a")

    File.write("a.txt", "amended\n")

    GT::GH.stub(:available?, false) do
      GT::Commands::Modify.new([]).run
    end

    local_sha = GT::Git.rev_parse("branch-a")
    remote_sha = GT::Git.rev_parse("origin/branch-a")
    assert_equal local_sha, remote_sha
  end
end
