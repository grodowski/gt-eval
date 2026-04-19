require "cli/ui"
require_relative "git"
require_relative "commands/create"
require_relative "commands/log"
require_relative "commands/navigate"
require_relative "commands/restack"
require_relative "commands/sync"
require_relative "commands/modify"

module GT
  class CLI
    COMMANDS = {
      "create"  => Commands::Create,
      "log"     => Commands::Log,
      "ls"      => Commands::Log,
      "up"      => Commands::Up,
      "down"    => Commands::Down,
      "top"     => Commands::Top,
      "restack" => Commands::Restack,
      "sync"    => Commands::Sync,
      "modify"  => Commands::Modify,
      "m"       => Commands::Modify,
    }.freeze

    def self.start(argv)
      ::CLI::UI::StdoutRouter.enable
      command_name = argv.shift
      klass = COMMANDS[command_name]
      unless klass
        ::CLI::UI.puts "{{red:Unknown command: #{command_name}}}"
        ::CLI::UI.puts "Available commands: #{COMMANDS.keys.uniq.join(', ')}"
        exit 1
      end
      klass.new(argv).run
    end
  end
end
