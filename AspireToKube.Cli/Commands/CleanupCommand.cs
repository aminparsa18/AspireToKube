using System.CommandLine;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AspireToKube.Cli.Commands;

internal static class CleanupCommand
{
    public static Command Create()
    {
        var cmd = new Command("cleanup", "Cleanup K8S resources");

        var distroOption = new Option<string>("--target", "-t")
        {
            Description = "K8S Cluster (k3s or Minikube)"
        };

        cmd.Options.Add(distroOption);

        cmd.SetAction(distro =>
        {
            var baseDir = AppContext.BaseDirectory;
            string scriptRunner = "";
            string scriptArgs = "";
            string scriptPath = "";

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                // Detect or validate distribution
                var target = distro.GetValue(distroOption)?.ToLower();

                if (target != "k3s" && target != "minikube")
                {
                    Console.Error.WriteLine($"Unsupported cluster: {target}");
                    Console.Error.WriteLine("Supported: k3s, minikube");
                    return 1;
                }

                Console.WriteLine($"Using: {target}");

                // Pick a concrete bash path
                var bashPath = File.Exists("/bin/bash")
                    ? "/bin/bash"
                    : File.Exists("/usr/bin/bash")
                        ? "/usr/bin/bash"
                        : "bash"; // last fallback

                // Select script based on distribution
                var scriptName = target == "k3s"
                    ? "cleanup-k3s.sh"
                    : "cleanup-minikube.sh";

                scriptPath = Path.Combine(baseDir, "scripts", "Linux", scriptName);
                scriptRunner = bashPath;
                scriptArgs = $"\"{scriptPath}\"";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                Console.WriteLine($"To be implemented...");
            }
            else
            {
                Console.Error.WriteLine("The 'init' command is only supported on Windows and Linux right now.");
                return 1;
            }

            if (!File.Exists(scriptPath))
            {
                Console.Error.WriteLine($"Init script not found at: {scriptPath}");
                return 1;
            }

            Console.WriteLine($"Running initialization script: {scriptPath}");
            Console.WriteLine();

            var exitCode = RunProcess(scriptRunner, scriptArgs);

            if (exitCode == 0)
            {
                Console.WriteLine();
                Console.WriteLine("Initialization completed successfully!");
            }
            else
            {
                Console.WriteLine();
                Console.Error.WriteLine($"Initialization failed with exit code: {exitCode}");
            }

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