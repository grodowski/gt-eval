# frozen_string_literal: true

module GT
  class App
    def initialize(argv, dir: nil)
      @argv = argv.dup
      @dir  = dir
    end

    def run
      ::CLI::UI::StdoutRouter.enable
      cmd = @argv.shift
      case cmd
      when "create"
        require_relative "commands/create"
        Commands::Create.new(@argv, dir: @dir).run
      when "log", "ls"
        require_relative "commands/log"
        Commands::Log.new(@argv, dir: @dir).run
      when "up"
        require_relative "commands/navigate"
        Commands::Navigate.new(:up, dir: @dir).run
      when "down"
        require_relative "commands/navigate"
        Commands::Navigate.new(:down, dir: @dir).run
      when "top"
        require_relative "commands/navigate"
        Commands::Navigate.new(:top, dir: @dir).run
      when "restack"
        require_relative "commands/restack"
        Commands::Restack.new(@argv, dir: @dir).run
      when "sync"
        require_relative "commands/sync"
        Commands::Sync.new(@argv, dir: @dir).run
      when "modify", "m"
        require_relative "commands/modify"
        Commands::Modify.new(@argv, dir: @dir).run
      else
        $stderr.puts "Unknown command: #{cmd}"
        $stderr.puts "Usage: gt <create|log|ls|up|down|top|restack|sync|modify>"
        exit 1
      end
    end
  end
end
