using System.CommandLine;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AspireToKube.Cli.Commands;

static internal class DeployCommand
{
    public static Command Create()
    {
        var cmd = new Command("deploy", "Deploy manifests to a local Kubernetes cluster");

        // --target k3s|minikube (required)
        var targetOption = new Option<string>("--target")
        {
            Description = "Cluster type to deploy to: k3s or minikube",
            Required = true
        };

        cmd.Options.Add(targetOption);

        cmd.SetAction(parseResult =>
        {
            var targetRaw = parseResult.GetValue(targetOption) ?? string.Empty;
            var target = targetRaw.Trim().ToLowerInvariant();

            if (target is not ("k3s" or "minikube"))
            {
                Console.Error.WriteLine("Invalid --target value. Allowed values: k3s, minikube.");
                return 1;
            }

            var baseDir = AppContext.BaseDirectory;

            string scriptRunner;
            string scriptArgs;
            string scriptPath;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                // pick a concrete bash path
                var bashPath = File.Exists("/bin/bash")
                    ? "/bin/bash"
                    : File.Exists("/usr/bin/bash")
                        ? "/usr/bin/bash"
                        : "bash";

                var scriptFile = target == "k3s"
                    ? "deploy2k3s.sh"
                    : "deploy2minikube.sh";

                // NOTE: "Linux" must match your folder name/casing in the nupkg
                scriptPath = Path.Combine(baseDir, "scripts", "Linux", scriptFile);
                scriptRunner = bashPath;
                scriptArgs = $"\"{scriptPath}\"";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                var scriptFile = target == "k3s"
                    ? "deploy2k3s.ps1"
                    : "deploy2minikube.ps1";

                // NOTE: "Windows" must match your folder name/casing in the nupkg
                scriptPath = Path.Combine(baseDir, "scripts", "Windows", scriptFile);
                scriptRunner = "powershell";
                scriptArgs = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"";
            }
            else
            {
                Console.Error.WriteLine("The 'deploy' command is only supported on Windows and Linux right now.");
                return 1;
            }

            if (!File.Exists(scriptPath))
            {
                Console.Error.WriteLine($"Deploy script not found at: {scriptPath}");
                return 1;
            }

            Console.WriteLine($"[deploy] Target : {target}");
            Console.WriteLine($"[deploy] Script : {scriptPath}");
            Console.WriteLine();

            var exitCode = RunProcess(scriptRunner, scriptArgs);
            return exitCode;
        });

        return cmd;
    }

    private static int RunProcess(string fileName, string arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,

            // Use the directory where the user ran "aspire2kube ..."
            WorkingDirectory = Environment.CurrentDirectory
        };

        using var proc = new Process { StartInfo = psi };

        proc.OutputDataReceived += (_, e) =>
        {
            if (e.Data is not null)
                Console.WriteLine(e.Data);
        };

        proc.ErrorDataReceived += (_, e) =>
        {
            if (e.Data is not null)
                Console.Error.WriteLine(e.Data);
        };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        proc.WaitForExit();
        return proc.ExitCode;
    }
}