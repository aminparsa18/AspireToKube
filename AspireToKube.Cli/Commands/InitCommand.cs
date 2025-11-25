using System.CommandLine;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AspireToKube.Cli.Commands;

internal static class InitCommand
{
    public static Command Create()
    {
        var cmd = new Command("init", "Initialize aspire2kube environment");

        cmd.SetAction(_ =>
        {
            var baseDir = AppContext.BaseDirectory;

            string scriptRunner;
            string scriptArgs;
            string scriptPath;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                scriptPath = Path.Combine(baseDir, "scripts", "linux", "install-k8s-prerequisites.sh");
                scriptRunner = "bash";
                scriptArgs = $"\"{scriptPath}\"";
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                scriptPath = Path.Combine(baseDir, "scripts", "windows", "install-k8s-prerequisites.ps1");
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