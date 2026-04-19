# frozen_string_literal: true

require_relative "test_helper"

class SmokeTest < GTTest
  def test_unknown_command_exits_with_error
    assert_raises(SystemExit) do
      run_gt("nonexistent")
    end
  end
end
