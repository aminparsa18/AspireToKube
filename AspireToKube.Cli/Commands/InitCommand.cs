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
            Description = "Linux distribution (ubuntu, debian, fedora, rocky, rhel, or auto-detect)",
            DefaultValueFactory = (x) => "auto"
        };

        var k8sTypeOption = new Option<string>("--k8s-type", "-k")
        {
            Description = "Kubernetes type (k3s or minikube)",
            DefaultValueFactory = (x) => "k3s"
        };

        cmd.Options.Add(distroOption);
        cmd.Options.Add(k8sTypeOption);

        cmd.SetAction(parseResult =>
        {
            var baseDir = AppContext.BaseDirectory;
            string scriptRunner;
            string scriptArgs;
            string scriptPath;

            // Get option values from parseResult
            var distroValue = (parseResult.GetValue(distroOption) ?? "auto").Trim().ToLowerInvariant();
            var k8sTypeValue = (parseResult.GetValue(k8sTypeOption) ?? "k3s").Trim().ToLowerInvariant();

            // Validate k8s type
            if (k8sTypeValue != "k3s" && k8sTypeValue != "minikube")
            {
                Console.Error.WriteLine($"Invalid --k8s-type value: {k8sTypeValue}");
                Console.Error.WriteLine("Allowed values: k3s, minikube");
                return 1;
            }

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                // Detect or validate distribution
                var detectedDistro = distroValue == "auto"
                    ? DetectLinuxDistro()
                    : NormalizeDistroName(distroValue);

                if (detectedDistro == "unknown")
                {
                    Console.Error.WriteLine("Could not detect Linux distribution. Please specify using --distro option.");
                    Console.Error.WriteLine("Supported distributions: ubuntu, debian, fedora, rocky, rhel");
                    return 1;
                }

                // Validate supported distributions
                var supportedDistros = new[] { "ubuntu", "debian", "fedora", "rocky" };
                if (!supportedDistros.Contains(detectedDistro))
                {
                    Console.Error.WriteLine($"Unsupported distribution: {detectedDistro}");
                    Console.Error.WriteLine("Supported distributions: ubuntu, debian, fedora, rocky");
                    return 1;
                }

                Console.WriteLine($"Using distribution: {detectedDistro}");
                Console.WriteLine($"Using Kubernetes type: {k8sTypeValue}");

                // Pick a concrete bash path
                var bashPath = File.Exists("/bin/bash")
                    ? "/bin/bash"
                    : File.Exists("/usr/bin/bash")
                        ? "/usr/bin/bash"
                        : "bash"; // last fallback

                // Select script based on distribution and k8s type
                var scriptName = k8sTypeValue == "k3s"
                    ? $"install-k3s-prereqs-{detectedDistro}.sh"
                    : $"install-minikube-prereqs-{detectedDistro}.sh";

                scriptPath = Path.Combine(baseDir, "scripts", "Linux", scriptName);
                scriptRunner = bashPath;
                scriptArgs = $"\"{scriptPath}\"";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                if (distroValue != "auto" && distroValue != "windows")
                {
                    Console.WriteLine($"Note: --distro option ignored on Windows (specified: {distroValue})");
                }

                Console.WriteLine($"Using Kubernetes type: {k8sTypeValue}");

                // Windows script name based on k8s type
                var scriptFileName = k8sTypeValue == "k3s"
                    ? "install-k3s-prerequisites.ps1"
                    : "install-minikube-prerequisites.ps1";

                scriptPath = Path.Combine(baseDir, "scripts", "Windows", scriptFileName);
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
                Console.Error.WriteLine($"Expected location: {scriptPath}");
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

    private static string NormalizeDistroName(string distro)
    {
        // Normalize common distribution name variations
        return distro.ToLower() switch
        {
            "ubuntu" => "ubuntu",
            "debian" => "debian",
            "fedora" => "fedora",
            "rocky" or "rocky linux" or "rockylinux" => "rocky",
            "rhel" or "red hat" or "redhat" or "red hat enterprise linux" => "rocky", // RHEL uses Rocky scripts
            "centos" or "centos stream" => "rocky", // CentOS uses Rocky scripts
            "alma" or "almalinux" or "alma linux" => "rocky", // AlmaLinux uses Rocky scripts
            _ => distro.ToLower()
        };
    }

    private static string DetectLinuxDistro()
    {
        try
        {
            // Check /etc/os-release (standard method)
            if (File.Exists("/etc/os-release"))
            {
                var osRelease = File.ReadAllText("/etc/os-release").ToLower();

                // Ubuntu
                if (osRelease.Contains("ubuntu"))
                    return "ubuntu";

                // Debian
                if (osRelease.Contains("debian"))
                    return "debian";

                // Fedora
                if (osRelease.Contains("fedora"))
                    return "fedora";

                // Rocky Linux
                if (osRelease.Contains("rocky") || osRelease.Contains("rocky linux"))
                    return "rocky";

                // RHEL-based distributions that are compatible with Rocky scripts
                if (osRelease.Contains("red hat") || osRelease.Contains("rhel"))
                {
                    Console.WriteLine("RHEL detected. Using Rocky Linux scripts (compatible).");
                    return "rocky";
                }

                // CentOS
                if (osRelease.Contains("centos"))
                {
                    Console.WriteLine("CentOS detected. Using Rocky Linux scripts (compatible).");
                    return "rocky";
                }

                // AlmaLinux
                if (osRelease.Contains("almalinux") || osRelease.Contains("alma"))
                {
                    Console.WriteLine("AlmaLinux detected. Using Rocky Linux scripts (compatible).");
                    return "rocky";
                }
            }

            // Fallback: check specific files
            if (File.Exists("/etc/lsb-release"))
            {
                var lsbRelease = File.ReadAllText("/etc/lsb-release").ToLower();
                if (lsbRelease.Contains("ubuntu"))
                    return "ubuntu";
                if (lsbRelease.Contains("debian"))
                    return "debian";
            }

            if (File.Exists("/etc/redhat-release"))
            {
                var redhatRelease = File.ReadAllText("/etc/redhat-release").ToLower();

                if (redhatRelease.Contains("rocky"))
                    return "rocky";

                if (redhatRelease.Contains("fedora"))
                    return "fedora";

                // CentOS, RHEL, AlmaLinux can use Rocky scripts
                if (redhatRelease.Contains("centos") ||
                    redhatRelease.Contains("red hat") ||
                    redhatRelease.Contains("rhel") ||
                    redhatRelease.Contains("alma"))
                {
                    Console.WriteLine($"RHEL-based distribution detected. Using Rocky Linux scripts (compatible).");
                    return "rocky";
                }
            }

            // Check for Debian
            if (File.Exists("/etc/debian_version"))
            {
                return "debian";
            }

            // Check for Fedora
            if (File.Exists("/etc/fedora-release"))
            {
                return "fedora";
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