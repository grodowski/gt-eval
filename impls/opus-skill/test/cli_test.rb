# frozen_string_literal: true

require_relative "test_helper"

class CLITest < GTTest
  def test_log_command_dispatches
    run_gt("log")
  end

  def test_ls_alias
    run_gt("ls")
  end

  def test_up_command_dispatches
    # No gt branches, so exits 1
    assert_raises(SystemExit) { run_gt("up") }
  end

  def test_down_command_dispatches
    assert_raises(SystemExit) { run_gt("down") }
  end

  def test_top_command_dispatches
    assert_raises(SystemExit) { run_gt("top") }
  end

  def test_restack_command_dispatches
    assert_raises(SystemExit) { run_gt("restack") }
  end

  def test_sync_command_dispatches
    assert_raises(SystemExit) { run_gt("sync") }
  end

  def test_modify_command_dispatches
    assert_raises(SystemExit) { run_gt("modify") }
  end

  def test_m_alias
    assert_raises(SystemExit) { run_gt("m") }
  end
end
