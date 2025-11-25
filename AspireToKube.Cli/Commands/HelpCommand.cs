using System.CommandLine;

namespace AspireToKube.Cli.Commands;

internal static class HelpCommand
{
    public static Command Create()
    {
        var help = new Command("help", "Show help and usage information for aspire2kube");

        help.SetAction(_ =>
        {
            Console.WriteLine();
            Console.WriteLine("Aspire2Kube CLI");
            Console.WriteLine("----------------");
            Console.WriteLine("Helper tool for exporting Aspire project images & manifests.");
            Console.WriteLine();
            Console.WriteLine("Usage:");
            Console.WriteLine("  aspire2kube help");
            Console.WriteLine("  aspire2kube generate [options]");
            Console.WriteLine();
            Console.WriteLine("Commands:");
            Console.WriteLine("  help                 Show this help text");
            Console.WriteLine("  generate             Run aspire2kube.ps1 to build migration package");
            Console.WriteLine();
            Console.WriteLine("generate options:");
            Console.WriteLine("  --export-method <value>    push | tar | skip");
            Console.WriteLine("                             If omitted, script will prompt.");
            Console.WriteLine();
            Console.WriteLine("  --aspirate-output <path>   Path to aspirate-output folder");
            Console.WriteLine("                             If omitted, script will prompt.");
            Console.WriteLine();
            Console.WriteLine("  --image <name>             Image name (can be repeated multiple times)");
            Console.WriteLine("                             If omitted, script will show interactive image selection.");
            Console.WriteLine();
            Console.WriteLine("  --docker-username <name>   Docker Hub username");
            Console.WriteLine("                             If omitted and export-method=push, script will prompt.");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  aspire2kube help");
            Console.WriteLine("  aspire2kube generate");
            Console.WriteLine("  aspire2kube generate --export-method push");
            Console.WriteLine("  aspire2kube generate --export-method tar --aspirate-output \"C:\\src\\Host\\aspirate-output\"");
            Console.WriteLine("  aspire2kube generate --export-method push --image ecs-api:latest --image ecs-admin:latest");
            Console.WriteLine();

            return 0;
        });
        return help;
    }
}