# frozen_string_literal: true

require_relative "test_helper"

class StackTest < GTTest
  def setup
    super
    # Create a stack: main -> branch-a -> branch-b
    File.write("file.txt", "v1")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    sandbox.run_git("checkout", "-b", "branch-a")
    GT::Git.set_parent("branch-a", "main")
    GT::Git.set_fork_point("branch-a", GT::Git.rev_parse("HEAD"))
    File.write("file.txt", "v2")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch a change")

    sandbox.run_git("checkout", "-b", "branch-b")
    GT::Git.set_parent("branch-b", "branch-a")
    GT::Git.set_fork_point("branch-b", GT::Git.rev_parse("HEAD"))
    File.write("file.txt", "v3")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch b change")
  end

  def test_find_root
    assert_equal "branch-a", GT::Stack.find_root("branch-b")
    assert_equal "branch-a", GT::Stack.find_root("branch-a")
  end

  def test_children_of
    children = GT::Stack.children_of("main")
    assert_includes children, "branch-a"

    children = GT::Stack.children_of("branch-a")
    assert_includes children, "branch-b"

    children = GT::Stack.children_of("branch-b")
    assert_empty children
  end

  def test_children_of_no_gt_branches
    # In a fresh sandbox with no gt config
    sandbox2 = GitSandbox.new
    Dir.chdir(sandbox2.repo_dir)
    children = GT::Stack.children_of("main")
    assert_empty children
    Dir.chdir(@sandbox.repo_dir)
    sandbox2.cleanup
  end

  def test_ordered_stack
    stack = GT::Stack.ordered_stack("branch-a")
    assert_equal ["branch-a", "branch-b"], stack
  end

  def test_full_stack_from
    stack = GT::Stack.full_stack_from("branch-b")
    assert_equal ["branch-a", "branch-b"], stack
  end

  def test_all_gt_branches
    branches = GT::Stack.all_gt_branches
    assert_includes branches, "branch-a"
    assert_includes branches, "branch-b"
  end

  def test_all_gt_branches_empty
    sandbox2 = GitSandbox.new
    Dir.chdir(sandbox2.repo_dir)
    branches = GT::Stack.all_gt_branches
    assert_empty branches
    Dir.chdir(@sandbox.repo_dir)
    sandbox2.cleanup
  end
end
