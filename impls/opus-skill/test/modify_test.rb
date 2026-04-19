# frozen_string_literal: true

require_relative "test_helper"

class ModifyTest < GTTest
  def test_modify_amends_and_restacks
    create_stack_with_push

    # Modify a file on branch-a
    sandbox.run_git("checkout", "branch-a")
    File.write("a.txt", "modified-a")

    run_gt("modify")

    # Should end on the tip
    assert_equal "branch-b", GT::Git.current_branch

    # branch-a should have the amended content
    sandbox.run_git("checkout", "branch-a")
    assert_equal "modified-a", File.read("a.txt")
  end

  def test_modify_alias_m
    create_stack_with_push

    sandbox.run_git("checkout", "branch-a")
    File.write("a.txt", "via-m")

    run_gt("m")

    assert_equal "branch-b", GT::Git.current_branch
    sandbox.run_git("checkout", "branch-a")
    assert_equal "via-m", File.read("a.txt")
  end

  def test_modify_with_no_changes
    create_stack_with_push
    sandbox.run_git("checkout", "branch-a")

    # No changes to amend — should still restack
    run_gt("modify")

    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_modify_with_push_failure
    create_stack_with_push
    sandbox.run_git("checkout", "branch-a")
    sandbox.run_git("remote", "remove", "origin")

    File.write("a.txt", "no-push-content")

    run_gt("modify")

    assert_equal "branch-b", GT::Git.current_branch
  end

  private

  def create_stack_with_push
    File.write("base.txt", "base")
    sandbox.run_git("add", "base.txt")
    sandbox.run_git("commit", "-m", "add base")

    sandbox.run_git("checkout", "-b", "branch-a")
    GT::Git.set_parent("branch-a", "main")
    GT::Git.set_fork_point("branch-a", GT::Git.rev_parse("main"))
    File.write("a.txt", "branch-a-content")
    sandbox.run_git("add", "a.txt")
    sandbox.run_git("commit", "-m", "branch a change")
    sandbox.run_git("push", "-u", "origin", "branch-a")

    sandbox.run_git("checkout", "-b", "branch-b")
    GT::Git.set_parent("branch-b", "branch-a")
    GT::Git.set_fork_point("branch-b", GT::Git.rev_parse("branch-a"))
    File.write("b.txt", "branch-b-content")
    sandbox.run_git("add", "b.txt")
    sandbox.run_git("commit", "-m", "branch b change")
    sandbox.run_git("push", "-u", "origin", "branch-b")
  end
end
