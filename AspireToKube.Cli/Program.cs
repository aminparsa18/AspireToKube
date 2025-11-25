using AspireToKube.Cli.Commands;
using System.CommandLine;

var root = new RootCommand("Aspire to Kubernetes helper tool (front-end for aspire2kube.ps1)");

root.Subcommands.Add(GenerateCommand.Create());
root.Subcommands.Add(HelpCommand.Create());
root.Subcommands.Add(InitCommand.Create());

// If no args, default to `help`
var effectiveArgs = args.Length == 0 ? ["help"] : args;

// parse + invoke
var result = root.Parse(effectiveArgs);
return result.Invoke();