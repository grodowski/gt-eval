# frozen_string_literal: true

require "open3"

module GT
  module GH
    class NotInstalled < StandardError; end

    module_function

    def available?
      _out, _err, status = Open3.capture3("which", "gh")
      status.success?
    end

    # Run a gh command. Returns stdout on success, nil if gh not installed.
    # Raises on other failures.
    def run(*args)
      unless available?
        warn "gh CLI not installed — skipping GitHub operation"
        return nil
      end

      out, err, status = Open3.capture3("gh", *args)
      unless status.success?
        warn "gh #{args.first}: #{err.strip}"
        return nil
      end
      out.strip
    end
  end
end
