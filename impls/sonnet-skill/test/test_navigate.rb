require_relative "test_helper"
require_relative "git_sandbox"

class NavigateCommandTest < Minitest::Test
  include GitSandbox

  def setup
    super
    # Build stack: feature-a → feature-b → feature-c, start on feature-a
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a", "A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b", "B")
    system("git", "push", "-u", "origin", "feature-b", [:out, :err] => File::NULL)

    make_gt_branch("feature-c", "feature-b")
    make_commit("c.txt", "c", "C")

    # Start at the bottom
    system("git", "checkout", "feature-a", [:out, :err] => File::NULL)
  end

  # ---- gt up ----

  def test_up_moves_to_child_branch
    GT::Commands::Up.new([]).run
    assert_equal "feature-b", GT::Git.current_branch
  end

  def test_up_from_middle_moves_to_tip
    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
    GT::Commands::Up.new([]).run
    assert_equal "feature-c", GT::Git.current_branch
  end

  def test_up_at_top_exits
    system("git", "checkout", "feature-c", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Up.new([]).run }
    assert_equal 1, e.status
    assert_equal "feature-c", GT::Git.current_branch
  end

  def test_up_not_in_stack_exits
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Up.new([]).run }
    assert_equal 1, e.status
  end

  # ---- gt down ----

  def test_down_moves_to_parent_branch
    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
    GT::Commands::Down.new([]).run
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_down_from_tip_moves_to_middle
    system("git", "checkout", "feature-c", [:out, :err] => File::NULL)
    GT::Commands::Down.new([]).run
    assert_equal "feature-b", GT::Git.current_branch
  end

  def test_down_at_bottom_exits
    e = assert_raises(SystemExit) { GT::Commands::Down.new([]).run }
    assert_equal 1, e.status
    assert_equal "feature-a", GT::Git.current_branch
  end

  def test_down_not_in_stack_exits
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Down.new([]).run }
    assert_equal 1, e.status
  end

  # ---- gt top ----

  def test_top_moves_to_tip
    GT::Commands::Top.new([]).run
    assert_equal "feature-c", GT::Git.current_branch
  end

  def test_top_from_middle_moves_to_tip
    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
    GT::Commands::Top.new([]).run
    assert_equal "feature-c", GT::Git.current_branch
  end

  def test_top_when_already_at_top_exits
    system("git", "checkout", "feature-c", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Top.new([]).run }
    assert_equal 1, e.status
  end

  def test_top_not_in_stack_exits
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Top.new([]).run }
    assert_equal 1, e.status
  end
end
