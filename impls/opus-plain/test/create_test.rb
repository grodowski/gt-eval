# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/create"

class CreateTest < Minitest::Test
  include GitSandbox

  def test_create_basic
    # Make a change on main
    File.write("file.txt", "hello\n")
    system("git", "add", "file.txt", out: File::NULL, err: File::NULL)

    # Stub GH to avoid actual gh calls
    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["feature-a", "-m", "Add feature A"]).run
    end

    # Should be on the new branch
    assert_equal "feature-a", GT::Git.current_branch

    # Parent metadata should be set
    assert_equal "main", GT::Git.gt_parent("feature-a")
    assert GT::Git.gt_fork_point("feature-a")

    # The commit should exist
    log = GT::Git.run("log", "--oneline", "-1")
    assert_includes log, "Add feature A"
  end

  def test_create_sets_fork_point_to_parent_sha
    make_commit("a.txt", message: "base")
    expected_sha = GT::Git.rev_parse("HEAD")

    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["branch-b"]).run
    end

    assert_equal expected_sha, GT::Git.gt_fork_point("branch-b")
  end

  def test_create_stacked
    # Create first branch
    make_commit("a.txt", message: "change a")
    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["branch-a", "-m", "Branch A"]).run
    end

    # Create second branch on top
    make_commit("b.txt", message: "change b")
    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["branch-b", "-m", "Branch B"]).run
    end

    assert_equal "branch-b", GT::Git.current_branch
    assert_equal "branch-a", GT::Git.gt_parent("branch-b")
    assert_equal "main", GT::Git.gt_parent("branch-a")
  end

  def test_create_without_name_exits
    assert_raises(SystemExit) do
      GT::Commands::Create.new([]).run
    end
  end

  def test_create_with_default_message
    make_commit("x.txt", message: "setup")

    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["my-feature"]).run
    end

    assert_equal "my-feature", GT::Git.current_branch
    assert_equal "main", GT::Git.gt_parent("my-feature")
  end

  def test_create_pushes_to_remote
    make_commit("p.txt", message: "for push")

    GT::GH.stub(:run, nil) do
      GT::Commands::Create.new(["pushed-branch", "-m", "push test"]).run
    end

    # Verify branch exists on remote
    remote_branches = GT::Git.run("ls-remote", "--heads", "origin", "pushed-branch")
    assert_includes remote_branches, "pushed-branch"
  end
end
