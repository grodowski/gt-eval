# frozen_string_literal: true

require "cli/ui"

module GT
  class CLI
    def initialize(args)
      @args = args
    end

    def run
      ::CLI::UI::StdoutRouter.enable
      command = @args.shift

      case command
      when "create"
        require_relative "commands/create"
        Commands::Create.new(@args).run
      when "log", "ls"
        require_relative "commands/log"
        Commands::Log.new(@args).run
      when "up"
        require_relative "commands/up"
        Commands::Up.new(@args).run
      when "down"
        require_relative "commands/down"
        Commands::Down.new(@args).run
      when "top"
        require_relative "commands/top"
        Commands::Top.new(@args).run
      when "restack"
        require_relative "commands/restack"
        Commands::Restack.new(@args).run
      when "sync"
        require_relative "commands/sync"
        Commands::Sync.new(@args).run
      when "modify", "m"
        require_relative "commands/modify"
        Commands::Modify.new(@args).run
      when "--version", "-v"
        puts "gt #{GT::VERSION}"
      else
        print_usage
        exit 1
      end
    end

    private

    def print_usage
      puts "Usage: gt <command> [options]"
      puts ""
      puts "Commands:"
      puts "  create <name> [-m <msg>]  Create a new branch in the stack"
      puts "  log / ls                  Show the current stack"
      puts "  up                        Move up the stack"
      puts "  down                      Move down the stack"
      puts "  top                       Move to the top of the stack"
      puts "  restack                   Rebase the stack"
      puts "  sync                      Pull main and restack"
      puts "  modify / m                Amend and restack"
    end
  end
end
