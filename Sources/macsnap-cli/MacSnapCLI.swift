import ArgumentParser
import MacSnapCore

/// Main CLI entry point
@main
struct MacSnapCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "macsnap",
        abstract: "A lightweight screenshot tool for macOS",
        version: "1.0.0",
        subcommands: [
            CaptureCommand.self,
            ConfigCommand.self,
            ListConfigCommand.self,
            ResetConfigCommand.self
        ],
        defaultSubcommand: CaptureCommand.self
    )
}
