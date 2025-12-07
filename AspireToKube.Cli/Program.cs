using AspireToKube.Cli.Commands;
using System.CommandLine;

var root = new RootCommand("Aspire to Kubernetes helper tool");

root.Subcommands.Add(InitCommand.Create());
root.Subcommands.Add(DestroyCommand.Create());
root.Subcommands.Add(DeployCommand.Create());
root.Subcommands.Add(GenerateCommand.Create());
root.Subcommands.Add(HelpCommand.Create());

// If no args, default to `help`
var effectiveArgs = args.Length == 0 ? ["help"] : args;

// parse + invoke
var result = root.Parse(effectiveArgs);
return result.Invoke();