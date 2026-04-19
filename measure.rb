#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Usage: ruby measure.rb <impl-dir>
# Reads the most recent Claude Code transcript for the given project dir
# and prints benchmark metrics.

require "json"
require "time"
require "open3"

impl_dir = ARGV[0] or abort "Usage: measure.rb <impl-dir>"
impl_dir = File.expand_path(impl_dir)

# Find the most recent transcript for this project
project_key = impl_dir.gsub("/", "-")
transcripts_dir = File.expand_path("~/.claude/projects/#{project_key}")
transcripts = Dir["#{transcripts_dir}/*.jsonl"].sort_by { |f| File.mtime(f) }
abort "No transcript found in #{transcripts_dir}" if transcripts.empty?

lines = transcripts.flat_map { |t| File.readlines(t).map { |l| JSON.parse(l) rescue nil }.compact }

# ── Duration (sum across sessions) ────────────────────────────────────────────
IDLE_THRESHOLD = 300 # seconds; gaps longer than this are not counted
total_secs = transcripts.sum do |t|
  ts = File.readlines(t).map { |l| JSON.parse(l) rescue nil }.compact
            .map { |l| l["timestamp"] }.compact.map { |s| Time.parse(s) }
  next 0 if ts.size < 2
  ts.each_cons(2).sum { |a, b| gap = b - a; gap < IDLE_THRESHOLD ? gap : 0 }
end.to_i
duration_str = "%d:%02d:%02d" % [total_secs / 3600, (total_secs % 3600) / 60, total_secs % 60]

# ── Tool calls ────────────────────────────────────────────────────────────────
tool_uses = lines.select { |l| Array(l.dig("message", "content")).any? { |c| c.is_a?(Hash) && c["type"] == "tool_use" } }
              .flat_map { |l| Array(l.dig("message", "content")).select { |c| c.is_a?(Hash) && c["type"] == "tool_use" } }

tool_counts = tool_uses.group_by { |t| t["name"] }.transform_values(&:count)
total_tool_calls = tool_uses.count

# ── Cost (tokens) ─────────────────────────────────────────────────────────────
usage_entries = lines.select { |l| l.dig("message", "usage") }
input_tokens         = usage_entries.sum { |l| l.dig("message", "usage", "input_tokens").to_i }
cache_write_tokens   = usage_entries.sum { |l| l.dig("message", "usage", "cache_creation_input_tokens").to_i }
cache_read_tokens    = usage_entries.sum { |l| l.dig("message", "usage", "cache_read_input_tokens").to_i }
output_tokens        = usage_entries.sum { |l| l.dig("message", "usage", "output_tokens").to_i }
total_input_tokens   = input_tokens + cache_write_tokens + cache_read_tokens

# Detect model from transcript (check for model field in messages)
model_info = lines.find { |l| l.dig("message", "model") }&.dig("message", "model") ||
             lines.find { |l| l["model"] }&.dig("model") ||
             "claude-sonnet-4-6" # fallback

# Pricing for Claude 4.6 models (per 1M tokens)
# Cache write = 1.25x input; cache read = 0.1x input
if model_info.include?("opus")
  input_rate, output_rate = 5.0, 25.0  # Opus 4.6: $5/$25
  model_display = "Opus 4.6"
else
  input_rate, output_rate = 3.0, 15.0  # Sonnet 4.6: $3/$15
  model_display = "Sonnet 4.6"
end
cache_write_rate = input_rate * 1.25
cache_read_rate  = input_rate * 0.1

approx_cost = (
  input_tokens       * input_rate       +
  cache_write_tokens * cache_write_rate +
  cache_read_tokens  * cache_read_rate  +
  output_tokens      * output_rate
) / 1_000_000

# ── Commits ───────────────────────────────────────────────────────────────────
git_log, _, git_st = Open3.capture3("git", "-C", impl_dir, "log", "--oneline")
commits = git_log.strip.split("\n")
commit_count = commits.size

# ── Lines of code ─────────────────────────────────────────────────────────────
lib_files  = Dir["#{impl_dir}/lib/**/*.rb"]
test_files = Dir["#{impl_dir}/test/**/*.rb"]
lib_loc   = lib_files.sum  { |f| File.readlines(f).count { |l| l.strip != "" && !l.strip.start_with?("#") } }
test_loc  = test_files.sum { |f| File.readlines(f).count { |l| l.strip != "" && !l.strip.start_with?("#") } }
test_count = test_files.sum { |f| File.readlines(f).count { |l| l.match?(/^\s*def test_/) } }

# ── Simplify skill invocations ────────────────────────────────────────────────
skill_log = File.join(impl_dir, ".claude", "skill_log.txt")
simplify_count = if File.exist?(skill_log)
  File.readlines(skill_log).count { |l| l.include?("simplify") }
else
  "n/a (no skill_log.txt)"
end

# ── Harness result ────────────────────────────────────────────────────────────
gt_bin = File.join(impl_dir, "bin", "gt")
harness = File.expand_path("../harness.rb", __FILE__)
if File.exist?(gt_bin)
  harness_out, _, harness_st = Open3.capture3(
    { "GT_BIN" => gt_bin },
    "ruby", harness,
    chdir: impl_dir
  )
  harness_summary = harness_out.lines.grep(/runs,/).first&.strip || "could not parse"
else
  harness_summary = "bin/gt not found"
end

# ── Undercover feedback loop ──────────────────────────────────────────────────
# tool_use IDs for bash calls that ran undercover
undercover_use_ids = tool_uses.select { |t|
  t["name"] == "Bash" && t.dig("input", "command").to_s.include?("undercover")
}.map { |t| t["id"] }.to_set

# tool_results are in user-role messages
tool_results = lines
  .select { |l| l.dig("message", "role") == "user" }
  .flat_map { |l| Array(l.dig("message", "content")) }
  .select { |c| c.is_a?(Hash) && c["type"] == "tool_result" }

undercover_runs = 0
undercover_runs_with_warnings = 0
tool_results.each do |r|
  next unless undercover_use_ids.include?(r["tool_use_id"])
  text = r["content"].to_s
  next unless text.include?("undercover") || text.include?("warnings")
  undercover_runs += 1
  total = text.scan(/"total_warnings":\s*(\d+)/).flatten.map(&:to_i).max.to_i
  undercover_runs_with_warnings += 1 if total > 0
end

# ── Coverage (from SimpleCov .last_run.json) ──────────────────────────────────
last_run = File.join(impl_dir, "coverage", ".last_run.json")
line_cov, branch_cov = if File.exist?(last_run)
  data = JSON.parse(File.read(last_run))
  [data.dig("result", "line"), data.dig("result", "branch")]
else
  ["n/a", "n/a"]
end

# ── Conversation turns ────────────────────────────────────────────────────────
assistant_turns = lines.count { |l| l.dig("message", "role") == "assistant" }

# ── Self-corrections (heuristic: bash calls that run tests mid-session) ───────
test_runs = tool_uses.count do |t|
  t["name"] == "Bash" && t.dig("input", "command").to_s.match?(/rake test|ruby.*test|minitest/)
end

# ── Output ────────────────────────────────────────────────────────────────────
puts "=" * 50
puts "METRICS: #{File.basename(impl_dir)}"
puts "=" * 50
puts "Sessions:              #{transcripts.size}"
puts "Duration:              #{duration_str}"
puts "Harness result:        #{harness_summary}"
puts "Commits:               #{commit_count}"
puts ""
puts "Lib LOC:               #{lib_loc}"
puts "Test LOC:              #{test_loc}"
puts "Test count:            #{test_count}"
puts "Test/impl ratio:       #{test_loc.zero? ? "n/a" : (test_loc.to_f / lib_loc).round(2)}"
puts "Line coverage:         #{line_cov}%"
puts "Branch coverage:       #{branch_cov}%"
puts ""
puts "Total tool calls:      #{total_tool_calls}"
puts "  Bash:                #{tool_counts["Bash"].to_i}"
puts "  Write/Edit:          #{tool_counts["Write"].to_i + tool_counts["Edit"].to_i}"
puts "  Read/Glob/Grep:      #{tool_counts["Read"].to_i + tool_counts["Glob"].to_i + tool_counts["Grep"].to_i}"
puts "Test runs (mid-sess):  #{test_runs}"
puts ""
def fmt(n) = n.to_s.reverse.scan(/.{1,3}/).join(",").reverse
puts "Turns (assistant msgs): #{assistant_turns}"
puts "Input tokens:           #{fmt(input_tokens)}"
puts "  Cache write tokens:   #{fmt(cache_write_tokens)}"
puts "  Cache read tokens:    #{fmt(cache_read_tokens)}"
puts "Output tokens:          #{fmt(output_tokens)}"
puts "Total input tokens:     #{fmt(total_input_tokens)}"
puts "Approx cost (#{model_display}): $#{approx_cost.round(4)}"
puts ""
puts "Undercover runs:       #{undercover_runs}"
puts "Undercover w/ warnings:#{undercover_runs_with_warnings}"
puts "Simplify invocations:  #{simplify_count}"
puts ""
puts "Top tool calls:"
tool_counts.sort_by { |_, v| -v }.first(5).each { |name, count| puts "  #{name}: #{count}" }
