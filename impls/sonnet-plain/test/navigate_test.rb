# frozen_string_literal: true

require_relative "test_helper"

class NavigateTest < Minitest::Test
  include GitSandbox

  def setup_three_branch_stack(local_dir)
    File.write(File.join(local_dir, "README.md"), "a\n")
    gt(local_dir, "create", "feature-a", "-m", "A")

    File.write(File.join(local_dir, "b.txt"), "b\n")
    git!(local_dir, "git", "add", "b.txt")
    gt(local_dir, "create", "feature-b", "-m", "B")

    File.write(File.join(local_dir, "c.txt"), "c\n")
    git!(local_dir, "git", "add", "c.txt")
    gt(local_dir, "create", "feature-c", "-m", "C")
    # Now on feature-c
  end

  def test_up_moves_to_next_branch
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      # Go down to feature-a first
      git!(local_dir, "git", "checkout", "feature-a")

      gt(local_dir, "up")
      assert_equal "feature-b", current_branch(local_dir)
    end
  end

  def test_down_moves_to_parent_branch
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      # On feature-c
      gt(local_dir, "down")
      assert_equal "feature-b", current_branch(local_dir)
    end
  end

  def test_top_goes_to_tip
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      git!(local_dir, "git", "checkout", "feature-a")

      gt(local_dir, "top")
      assert_equal "feature-c", current_branch(local_dir)
    end
  end

  def test_top_from_tip_stays
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      # Already on feature-c (top)
      gt(local_dir, "top")
      assert_equal "feature-c", current_branch(local_dir)
    end
  end

  def test_up_at_top_exits_1
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      # On feature-c (top), gt up should exit 1
      assert_raises(SystemExit) { gt(local_dir, "up") }
    end
  end

  def test_down_at_bottom_exits_1
    with_sandbox do |local_dir, _remote_dir|
      setup_three_branch_stack(local_dir)
      git!(local_dir, "git", "checkout", "feature-a")
      assert_raises(SystemExit) { gt(local_dir, "down") }
    end
  end

  def test_navigate_not_in_stack_exits_1
    with_sandbox do |local_dir, _remote_dir|
      # On main, not in a stack
      assert_raises(SystemExit) { gt(local_dir, "up") }
      assert_raises(SystemExit) { gt(local_dir, "down") }
      assert_raises(SystemExit) { gt(local_dir, "top") }
    end
  end
end
