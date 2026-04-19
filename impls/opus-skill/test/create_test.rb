# frozen_string_literal: true

require_relative "test_helper"

class CreateTest < GTTest
  def test_create_branch_from_main
    File.write("file.txt", "hello")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    # Modify a tracked file so there's something to commit
    File.write("file.txt", "modified")

    run_gt("create", "feature-a", "-m", "Add feature A")

    assert_equal "feature-a", GT::Git.current_branch
    assert_equal "main", GT::Git.parent_of("feature-a")
    assert GT::Git.fork_point_of("feature-a"), "fork point should be set"
  end

  def test_create_stacked_branches
    File.write("file.txt", "v1")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    File.write("file.txt", "v2")
    run_gt("create", "branch-a", "-m", "Branch A")

    File.write("file.txt", "v3")
    run_gt("create", "branch-b", "-m", "Branch B")

    assert_equal "branch-b", GT::Git.current_branch
    assert_equal "branch-a", GT::Git.parent_of("branch-b")
    assert_equal "main", GT::Git.parent_of("branch-a")
  end

  def test_create_with_default_message
    File.write("file.txt", "hello")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    File.write("file.txt", "changed")
    run_gt("create", "my-feature")

    assert_equal "my-feature", GT::Git.current_branch
  end

  def test_create_does_not_modify_parent_branch
    File.write("file.txt", "hello")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")
    main_sha = GT::Git.rev_parse("HEAD")

    File.write("file.txt", "modified")
    run_gt("create", "feature-x", "-m", "Feature X")

    # main should still be at the same commit
    assert_equal main_sha, GT::Git.rev_parse("main")
  end

  def test_create_without_name_exits
    assert_raises(SystemExit) do
      run_gt("create")
    end
  end

  def test_create_with_nothing_to_commit
    # No changes to tracked files — should still create branch
    run_gt("create", "empty-branch", "-m", "empty")

    assert_equal "empty-branch", GT::Git.current_branch
    assert_equal "main", GT::Git.parent_of("empty-branch")
  end

  def test_create_pushes_to_remote
    File.write("file.txt", "hello")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    File.write("file.txt", "changed")
    run_gt("create", "pushed-branch", "-m", "push test")

    # Check that the branch exists on the remote
    remote_branches = sandbox.run_git("ls-remote", "--heads", "origin", "pushed-branch")
    refute_empty remote_branches
  end

  def test_create_with_push_failure
    # Remove the remote so push fails
    sandbox.run_git("remote", "remove", "origin")

    run_gt("create", "no-remote-branch", "-m", "no remote")

    assert_equal "no-remote-branch", GT::Git.current_branch
    assert_equal "main", GT::Git.parent_of("no-remote-branch")
  end
end
