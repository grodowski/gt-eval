require "simplecov"
require "undercover/simplecov_formatter"

SimpleCov.formatter = SimpleCov::Formatter::Undercover

SimpleCov.start do
  add_filter("/test/")
  enable_coverage(:branch)
end

require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.join(__dir__, "../lib")
require "gt"
