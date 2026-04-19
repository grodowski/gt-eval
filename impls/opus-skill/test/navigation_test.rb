# frozen_string_literal: true

require_relative "test_helper"

class NavigationTest < GTTest
  def setup
    super
    create_stack
  end

  # gt up tests
  def test_up_moves_to_child
    sandbox.run_git("checkout", "branch-a")
    run_gt("up")
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_up_at_top_exits_1
    sandbox.run_git("checkout", "branch-b")
    err = assert_raises(SystemExit) { run_gt("up") }
    assert_equal 1, err.status
  end

  def test_up_from_main_to_first_child
    sandbox.run_git("checkout", "main")
    run_gt("up")
    assert_equal "branch-a", GT::Git.current_branch
  end

  # gt down tests
  def test_down_moves_to_parent
    sandbox.run_git("checkout", "branch-b")
    run_gt("down")
    assert_equal "branch-a", GT::Git.current_branch
  end

  def test_down_to_main
    sandbox.run_git("checkout", "branch-a")
    run_gt("down")
    assert_equal "main", GT::Git.current_branch
  end

  def test_down_at_bottom_exits_1
    sandbox.run_git("checkout", "main")
    err = assert_raises(SystemExit) { run_gt("down") }
    assert_equal 1, err.status
  end

  # gt top tests
  def test_top_from_main
    sandbox.run_git("checkout", "main")
    run_gt("top")
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_top_from_middle
    sandbox.run_git("checkout", "branch-a")
    run_gt("top")
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_top_already_at_top_exits_1
    sandbox.run_git("checkout", "branch-b")
    err = assert_raises(SystemExit) { run_gt("top") }
    assert_equal 1, err.status
  end

  private

  def create_stack
    File.write("file.txt", "v1")
    sandbox.run_git("add", "file.txt")
    sandbox.run_git("commit", "-m", "add file")

    sandbox.run_git("checkout", "-b", "branch-a")
    GT::Git.set_parent("branch-a", "main")
    GT::Git.set_fork_point("branch-a", GT::Git.rev_parse("HEAD"))
    File.write("file.txt", "v2")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch a")

    sandbox.run_git("checkout", "-b", "branch-b")
    GT::Git.set_parent("branch-b", "branch-a")
    GT::Git.set_fork_point("branch-b", GT::Git.rev_parse("HEAD"))
    File.write("file.txt", "v3")
    sandbox.run_git("add", "-u")
    sandbox.run_git("commit", "-m", "branch b")
  end
end
