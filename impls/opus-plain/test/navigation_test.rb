# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/up"
require_relative "../lib/gt/commands/down"
require_relative "../lib/gt/commands/top"

class NavigationTest < Minitest::Test
  include GitSandbox

  def setup
    super
    # Build a 3-branch stack: main -> branch-a -> branch-b -> branch-c
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    create_gt_branch("branch-c", parent: "branch-b")
    make_commit("d.txt", message: "on c")
  end

  # --- gt up ---

  def test_up_from_bottom
    GT::Git.run("checkout", "branch-a")
    GT::Commands::Up.new([]).run
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_up_from_middle
    GT::Git.run("checkout", "branch-b")
    GT::Commands::Up.new([]).run
    assert_equal "branch-c", GT::Git.current_branch
  end

  def test_up_from_top_exits
    # Already on branch-c (top)
    assert_raises(SystemExit) do
      GT::Commands::Up.new([]).run
    end
  end

  def test_up_from_unmanaged_exits
    GT::Git.run("checkout", "main")
    assert_raises(SystemExit) do
      GT::Commands::Up.new([]).run
    end
  end

  # --- gt down ---

  def test_down_from_top
    GT::Commands::Down.new([]).run
    assert_equal "branch-b", GT::Git.current_branch
  end

  def test_down_from_middle
    GT::Git.run("checkout", "branch-b")
    GT::Commands::Down.new([]).run
    assert_equal "branch-a", GT::Git.current_branch
  end

  def test_down_from_bottom_exits
    GT::Git.run("checkout", "branch-a")
    assert_raises(SystemExit) do
      GT::Commands::Down.new([]).run
    end
  end

  # --- gt top ---

  def test_top_from_bottom
    GT::Git.run("checkout", "branch-a")
    GT::Commands::Top.new([]).run
    assert_equal "branch-c", GT::Git.current_branch
  end

  def test_top_from_main
    GT::Git.run("checkout", "main")
    GT::Commands::Top.new([]).run
    assert_equal "branch-c", GT::Git.current_branch
  end

  def test_top_already_at_top_exits
    # Already on branch-c
    assert_raises(SystemExit) do
      GT::Commands::Top.new([]).run
    end
  end

  def test_top_no_managed_branches
    # Start fresh - remove gt metadata
    GT::Git.run("checkout", "main")
    GT::Git.run("config", "--local", "--remove-section", "branch.branch-a")
    GT::Git.run("config", "--local", "--remove-section", "branch.branch-b")
    GT::Git.run("config", "--local", "--remove-section", "branch.branch-c")

    assert_raises(SystemExit) do
      GT::Commands::Top.new([]).run
    end
  end
end
