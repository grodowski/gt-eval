# frozen_string_literal: true

module GT
  class CLI
    def self.run(args)
      command = args.shift

      case command
      when "create"
        require_relative "commands/create"
        Commands::Create.run(args)
      when "log", "ls"
        require_relative "commands/log"
        Commands::Log.run(args)
      when "up"
        require_relative "commands/up"
        Commands::Up.run(args)
      when "down"
        require_relative "commands/down"
        Commands::Down.run(args)
      when "top"
        require_relative "commands/top"
        Commands::Top.run(args)
      when "restack"
        require_relative "commands/restack"
        Commands::Restack.run(args)
      when "sync"
        require_relative "commands/sync"
        Commands::Sync.run(args)
      when "modify", "m"
        require_relative "commands/modify"
        Commands::Modify.run(args)
      else
        $stderr.puts "Unknown command: #{command}"
        exit 1
      end
    end
  end
end
