using System.CommandLine;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace AspireToKube.Cli.Commands;

internal static class GenerateCommand
{
    public static Command Create()
    {
        var generate = new Command("generate", "Prepare migration package (images + manifests)");

        // --export-method push|tar|skip (optional)
        var exportMethodOption = new Option<string?>("--export-method")
        {
            Description = "Image export method: push | tar | skip. If omitted, script will prompt."
        };

        // --aspirate-output <path> (optional)
        var aspirateOutputOption = new Option<string?>("--aspirate-output")
        {
            Description = "Path to aspirate-output folder. If omitted, script will prompt."
        };

        // --image <name> (repeatable, optional)
        var imagesOption = new Option<string[]>("--image")
        {
            Description = "Image name(s) to operate on (can be specified multiple times). If omitted, script will show interactive image selection.",
            Arity = ArgumentArity.ZeroOrMore
        };

        // --docker-username <user> (optional)
        var dockerUsernameOption = new Option<string?>("--docker-username")
        {
            Description = "Docker Hub username. If omitted and export method is push, script will prompt."
        };

        generate.Options.Add(exportMethodOption);
        generate.Options.Add(aspirateOutputOption);
        generate.Options.Add(imagesOption);
        generate.Options.Add(dockerUsernameOption);

        // generate action
        generate.SetAction(parseResult =>
        {
            var exportMethod = parseResult.GetValue(exportMethodOption);
            var aspirateOutput = parseResult.GetValue(aspirateOutputOption);
            var images = parseResult.GetValue(imagesOption) ?? Array.Empty<string>();
            var dockerUser = parseResult.GetValue(dockerUsernameOption);

            int exitCode = RunGenerateScript(
                exportMethod,
                aspirateOutput,
                images,
                dockerUser
            );

            return exitCode;
        });

        return generate;
    }

    static int RunGenerateScript(
    string? exportMethod,
    string? aspirateOutputPath,
    string[] images,
    string? dockerUsername)
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            Console.Error.WriteLine("aspire2kube.ps1 currently only supports Windows. Linux/Mac version (bash) not wired yet.");
            return 1;
        }

        var baseDir = AppContext.BaseDirectory;

        // Must match how you include the script in your .csproj:
        // <Content Include="scripts\**\*">
        //   <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
        //   <PackagePath>tools\scripts\%(RecursiveDir)%(Filename)%(Extension)</PackagePath>
        // </Content>
        var scriptPath = System.IO.Path.Combine(baseDir, "scripts", "windows", "aspire2kube.ps1");

        if (!System.IO.File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"Could not find PowerShell script at: {scriptPath}");
            return 1;
        }

        var argBuilder = new StringBuilder();
        argBuilder.Append($"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\"");

        if (!string.IsNullOrWhiteSpace(exportMethod))
        {
            argBuilder.Append($" -ExportMethod {exportMethod}");
        }

        if (!string.IsNullOrWhiteSpace(aspirateOutputPath))
        {
            argBuilder.Append($" -AspirateOutputPath \"{aspirateOutputPath}\"");
        }

        if (images is { Length: > 0 })
        {
            foreach (var img in images)
            {
                if (!string.IsNullOrWhiteSpace(img))
                {
                    argBuilder.Append($" -Images \"{img}\"");
                }
            }
        }

        if (!string.IsNullOrWhiteSpace(dockerUsername))
        {
            argBuilder.Append($" -DockerUsername \"{dockerUsername}\"");
        }

        var powershellExe = FindPowerShell();

        Console.WriteLine($"[aspire2kube] Running: {powershellExe} {argBuilder}");

        return RunProcess(powershellExe, argBuilder.ToString());
    }

    static string FindPowerShell()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return "powershell";

        return "pwsh";
    }

    static int RunProcess(string fileName, string arguments)
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