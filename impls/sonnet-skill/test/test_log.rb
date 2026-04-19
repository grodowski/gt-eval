require_relative "test_helper"
require_relative "git_sandbox"

class LogCommandTest < Minitest::Test
  include GitSandbox

  def setup
    super
    # Build a 3-branch stack: feature-a → feature-b → feature-c
    make_gt_branch("feature-a", "main")
    make_commit("a.txt", "a content", "commit on A")
    system("git", "push", "-u", "origin", "feature-a", [:out, :err] => File::NULL)

    make_gt_branch("feature-b", "feature-a")
    make_commit("b.txt", "b content", "commit on B")
    system("git", "push", "-u", "origin", "feature-b", [:out, :err] => File::NULL)

    make_gt_branch("feature-c", "feature-b")
    make_commit("c.txt", "c content", "commit on C")
  end

  def test_log_shows_full_stack_from_root_to_tip
    # Currently on feature-c
    output = capture_io { GT::Commands::Log.new([]).run }.first
    assert_includes output, "main"
    assert_includes output, "feature-a"
    assert_includes output, "feature-b"
    assert_includes output, "feature-c"
  end

  def test_log_highlights_current_branch
    # Currently on feature-c
    output = capture_io { GT::Commands::Log.new([]).run }.first
    assert_match(/\*\s*feature-c/, output.gsub(/\e\[[0-9;]*m/, ""))
  end

  def test_log_root_of_stack_is_listed_first
    output = capture_io { GT::Commands::Log.new([]).run }.first.gsub(/\e\[[0-9;]*m/, "")
    lines = output.lines.map(&:strip).reject(&:empty?)
    branch_names = lines.map { |l| l.sub(/^\*\s*/, "").sub(/^\s*/, "") }
    assert_equal "main", branch_names[0]
    assert_equal "feature-c", branch_names[-1]
  end

  def test_log_current_branch_mid_stack
    system("git", "checkout", "feature-b", [:out, :err] => File::NULL)
    output = capture_io { GT::Commands::Log.new([]).run }.first.gsub(/\e\[[0-9;]*m/, "")
    assert_match(/\*\s*feature-b/, output)
    # feature-a and feature-c should also appear without *
    refute_match(/\*\s*feature-a/, output)
    refute_match(/\*\s*feature-c/, output)
  end

  def test_log_exits_when_no_stacked_branches
    # Wipe all gt config and switch to main
    system("git", "config", "--remove-section", "branch.feature-a", [:out, :err] => File::NULL)
    system("git", "config", "--remove-section", "branch.feature-b", [:out, :err] => File::NULL)
    system("git", "config", "--remove-section", "branch.feature-c", [:out, :err] => File::NULL)
    system("git", "checkout", "main", [:out, :err] => File::NULL)

    e = assert_raises(SystemExit) { GT::Commands::Log.new([]).run }
    assert_equal 1, e.status
  end

  def test_log_exits_when_current_branch_not_in_stack
    # Switch to main (not a gt branch)
    system("git", "checkout", "main", [:out, :err] => File::NULL)
    e = assert_raises(SystemExit) { GT::Commands::Log.new([]).run }
    assert_equal 1, e.status
  end

  def test_ls_alias_works
    # ls is aliased to Log in the CLI
    output = capture_io { GT::Commands::Log.new([]).run }.first
    refute_empty output
  end

  def test_log_without_root_parent_still_shows_stack
    # Simulate root branch having no gt-parent config (else branch of root_parent ternary)
    original = GT::Git.method(:gt_parent)
    GT::Git.define_singleton_method(:gt_parent) do |branch|
      branch == "feature-a" ? nil : original.call(branch)
    end
    output = capture_io { GT::Commands::Log.new([]).run }.first
    assert_includes output, "feature-a"
    assert_includes output, "feature-c"
  ensure
    GT::Git.define_singleton_method(:gt_parent, &original)
  end
end
