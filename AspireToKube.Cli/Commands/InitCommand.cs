using System.CommandLine;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AspireToKube.Cli.Commands;

internal static class InitCommand
{
    public static Command Create()
    {
        var cmd = new Command("init", "Initialize aspire2kube environment");

        var distroOption = new Option<string>("--distro", "-d")
        {
            Description = "Linux distribution (ubuntu, rocky, or auto-detect)"
        };

        cmd.Options.Add(distroOption);

        cmd.SetAction(distro =>
        {
            var baseDir = AppContext.BaseDirectory;
            string scriptRunner;
            string scriptArgs;
            string scriptPath;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                // Detect or validate distribution
                var detectedDistro = distro.GetValue(distroOption)!.Equals("auto", StringComparison.CurrentCultureIgnoreCase)
                    ? DetectLinuxDistro()
                    : distro.GetValue(distroOption)?.ToLower();

                if (detectedDistro == "unknown")
                {
                    Console.Error.WriteLine("Could not detect Linux distribution. Please specify using --distro option.");
                    Console.Error.WriteLine("Supported distributions: ubuntu, rocky");
                    return 1;
                }

                if (detectedDistro != "ubuntu" && detectedDistro != "rocky")
                {
                    Console.Error.WriteLine($"Unsupported distribution: {detectedDistro}");
                    Console.Error.WriteLine("Supported distributions: ubuntu, rocky");
                    return 1;
                }

                Console.WriteLine($"Using distribution: {detectedDistro}");

                // Pick a concrete bash path
                var bashPath = File.Exists("/bin/bash")
                    ? "/bin/bash"
                    : File.Exists("/usr/bin/bash")
                        ? "/usr/bin/bash"
                        : "bash"; // last fallback

                // Select script based on distribution
                var scriptName = detectedDistro == "ubuntu"
                    ? "install-k8s-prereqs-ubuntu.sh"
                    : "install-k8s-prereqs-rocky.sh";

                scriptPath = Path.Combine(baseDir, "scripts", "Linux", scriptName);
                scriptRunner = bashPath;
                scriptArgs = $"\"{scriptPath}\"";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                if (distro.GetValue(distroOption)?.ToLower() != "auto" && distro.GetValue(distroOption)?.ToLower() != "windows")
                {
                    Console.WriteLine($"Note: --distro option ignored on Windows (specified: {distro})");
                }

                scriptPath = Path.Combine(baseDir, "scripts", "Windows", "install-k8s-prerequisites.ps1");
                scriptRunner = "powershell";
                scriptArgs = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"";
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

    private static string DetectLinuxDistro()
    {
        try
        {
            // Check /etc/os-release (standard method)
            if (File.Exists("/etc/os-release"))
            {
                var osRelease = File.ReadAllText("/etc/os-release").ToLower();

                if (osRelease.Contains("ubuntu"))
                    return "ubuntu";

                if (osRelease.Contains("rocky") || osRelease.Contains("rocky linux"))
                    return "rocky";

                // Also check for RHEL-based distributions that are compatible with Rocky
                if (osRelease.Contains("red hat") || osRelease.Contains("rhel"))
                    return "rocky";

                if (osRelease.Contains("centos"))
                    return "rocky";

                // Debian can use Ubuntu script in most cases
                if (osRelease.Contains("debian"))
                {
                    Console.WriteLine("Debian detected. Using Ubuntu script (should be compatible).");
                    return "ubuntu";
                }
            }

            // Fallback: check specific files
            if (File.Exists("/etc/lsb-release"))
            {
                var lsbRelease = File.ReadAllText("/etc/lsb-release").ToLower();
                if (lsbRelease.Contains("ubuntu"))
                    return "ubuntu";
            }

            if (File.Exists("/etc/redhat-release"))
            {
                var redhatRelease = File.ReadAllText("/etc/redhat-release").ToLower();
                if (redhatRelease.Contains("rocky"))
                    return "rocky";

                // CentOS, RHEL, Fedora can use Rocky script
                if (redhatRelease.Contains("centos") ||
                    redhatRelease.Contains("red hat") ||
                    redhatRelease.Contains("rhel"))
                    return "rocky";
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Warning: Error detecting distribution: {ex.Message}");
        }

        return "unknown";
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