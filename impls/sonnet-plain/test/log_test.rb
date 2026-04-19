# frozen_string_literal: true

require_relative "test_helper"

class LogTest < Minitest::Test
  include GitSandbox

  def test_log_no_stack
    with_sandbox do |local_dir, _remote_dir|
      # main branch, no gt branches
      out, _err = capture_io { gt(local_dir, "log") }
      assert_includes out, "No gt-managed stack"
    end
  end

  def test_log_single_branch_stack
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "a\n")
      gt(local_dir, "create", "feature-a", "-m", "A")

      out, _err = capture_io { gt(local_dir, "log") }
      assert_includes out, "main"
      assert_includes out, "feature-a"
    end
  end

  def test_log_marks_current_branch
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "a\n")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      # Currently on feature-b
      out, _err = capture_io { gt(local_dir, "log") }
      lines = out.lines

      # feature-b line should have the marker
      feature_b_line = lines.find { |l| l.include?("feature-b") }
      assert_match(/▶/, feature_b_line)

      # feature-a line should NOT have the marker
      feature_a_line = lines.find { |l| l.include?("feature-a") }
      refute_match(/▶/, feature_a_line)
    end
  end

  def test_log_shows_stack_order
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "a\n")
      gt(local_dir, "create", "feature-a", "-m", "A")

      File.write(File.join(local_dir, "b.txt"), "b\n")
      git!(local_dir, "git", "add", "b.txt")
      gt(local_dir, "create", "feature-b", "-m", "B")

      out, _err = capture_io { gt(local_dir, "log") }

      main_pos     = out.index("main")
      feature_a_pos = out.index("feature-a")
      feature_b_pos = out.index("feature-b")

      assert main_pos < feature_a_pos, "main should appear before feature-a"
      assert feature_a_pos < feature_b_pos, "feature-a should appear before feature-b"
    end
  end

  def test_ls_alias
    with_sandbox do |local_dir, _remote_dir|
      File.write(File.join(local_dir, "README.md"), "a\n")
      gt(local_dir, "create", "feature-a", "-m", "A")

      log_out, = capture_io { gt(local_dir, "log") }
      ls_out,  = capture_io { gt(local_dir, "ls") }

      assert_equal log_out, ls_out
    end
  end
end
