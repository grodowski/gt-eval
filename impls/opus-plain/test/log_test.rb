# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gt/commands/log"

class LogTest < Minitest::Test
  include GitSandbox

  def test_log_empty_stack
    out = capture_output do
      GT::Commands::Log.new([]).run
    end
    assert_includes out, "No gt-managed branches found"
  end

  def test_log_single_branch
    make_commit("a.txt", message: "change")
    create_gt_branch("feature-a", parent: "main")
    make_commit("b.txt", message: "on feature-a")

    out = capture_output do
      GT::Commands::Log.new([]).run
    end

    assert_includes out, "main"
    assert_includes out, "feature-a"
  end

  def test_log_highlights_current_branch
    make_commit("a.txt", message: "change")
    create_gt_branch("feature-a", parent: "main")
    make_commit("b.txt", message: "on feature-a")

    out = capture_output do
      GT::Commands::Log.new([]).run
    end

    # Current branch should have the * marker
    assert_match(/\*.*feature-a/, out)
  end

  def test_log_stacked_branches
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    create_gt_branch("branch-c", parent: "branch-b")
    make_commit("d.txt", message: "on c")

    out = capture_output do
      GT::Commands::Log.new([]).run
    end

    lines = out.lines.map(&:strip)
    # Verify ordering: main, branch-a, branch-b, branch-c
    main_idx = lines.index { |l| l.include?("main") }
    a_idx = lines.index { |l| l.include?("branch-a") }
    b_idx = lines.index { |l| l.include?("branch-b") }
    c_idx = lines.index { |l| l.include?("branch-c") }

    assert main_idx < a_idx
    assert a_idx < b_idx
    assert b_idx < c_idx
  end

  def test_log_from_middle_of_stack
    make_commit("a.txt", message: "change a")
    create_gt_branch("branch-a", parent: "main")
    make_commit("b.txt", message: "on a")

    create_gt_branch("branch-b", parent: "branch-a")
    make_commit("c.txt", message: "on b")

    # Go back to branch-a
    GT::Git.run("checkout", "branch-a")

    out = capture_output do
      GT::Commands::Log.new([]).run
    end

    # Should still show the full stack
    assert_includes out, "branch-a"
    assert_includes out, "branch-b"
    assert_match(/\*.*branch-a/, out)
  end

  private

  def capture_output
    out = StringIO.new
    old_stdout = $stdout
    $stdout = out
    yield
    $stdout = old_stdout
    out.string
  end
end
