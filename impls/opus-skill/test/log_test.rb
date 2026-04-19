# frozen_string_literal: true

require_relative "test_helper"

class LogTest < GTTest
  def test_log_no_gt_branches
    output = capture_stdout { run_gt("log") }
    assert_match(/No gt-managed branches/, output)
  end

  def test_log_shows_stack
    create_stack

    sandbox.run_git("checkout", "branch-a")
    output = capture_stdout { run_gt("log") }

    assert_match(/main/, output)
    assert_match(/branch-a/, output)
    assert_match(/branch-b/, output)
    assert_match(/HEAD/, output)
  end

  def test_log_highlights_current_branch
    create_stack

    sandbox.run_git("checkout", "branch-b")
    output = capture_stdout { run_gt("log") }

    # branch-b should be highlighted as HEAD
    lines = output.lines
    branch_b_line = lines.find { |l| l.include?("branch-b") }
    assert_match(/HEAD/, branch_b_line)
  end

  def test_ls_alias
    output = capture_stdout { run_gt("ls") }
    assert_match(/No gt-managed branches/, output)
  end

  def test_log_from_main_with_gt_branches
    create_stack
    sandbox.run_git("checkout", "main")

    output = capture_stdout { run_gt("log") }
    assert_match(/branch-a/, output)
    assert_match(/branch-b/, output)
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

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
