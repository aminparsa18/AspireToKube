using System.CommandLine;

namespace AspireToKube.Cli.Commands;

internal static class HelpCommand
{
    public static Command Create()
    {
        var help = new Command("help", "Show help and usage information for aspire2kube");

        help.SetAction(parseResult =>
        {
            Console.WriteLine();
            Console.WriteLine("╔══════════════════════════════════════════════════════════════════╗");
            Console.WriteLine("║                     Aspire2Kube CLI v0.1.30                      ║");
            Console.WriteLine("╚══════════════════════════════════════════════════════════════════╝");
            Console.WriteLine();
            Console.WriteLine("A comprehensive tool for migrating .NET Aspire applications to Kubernetes");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  COMMANDS");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            // Help Command
            Console.WriteLine("  help");
            Console.WriteLine("    Show this help text");
            Console.WriteLine();

            // Init Command
            Console.WriteLine("  init");
            Console.WriteLine("    Initialize aspire2kube environment by installing Kubernetes");
            Console.WriteLine("    prerequisites (k3s or Minikube) on your system");
            Console.WriteLine();
            Console.WriteLine("    Options:");
            Console.WriteLine("      --distro, -d <value>    Linux distribution (ubuntu, debian, fedora,");
            Console.WriteLine("                              rocky, rhel, auto)");
            Console.WriteLine("                              Default: auto");
            Console.WriteLine();
            Console.WriteLine("      --k8s-type, -k <value>  Kubernetes type (k3s, minikube)");
            Console.WriteLine("                              Default: k3s");
            Console.WriteLine();
            Console.WriteLine("    Supported Distributions:");
            Console.WriteLine("      • Ubuntu (apt-based)");
            Console.WriteLine("      • Debian (apt-based)");
            Console.WriteLine("      • Fedora (dnf-based)");
            Console.WriteLine("      • Rocky Linux (dnf-based)");
            Console.WriteLine("      • RHEL (uses Rocky scripts)");
            Console.WriteLine("      • CentOS (uses Rocky scripts)");
            Console.WriteLine("      • AlmaLinux (uses Rocky scripts)");
            Console.WriteLine();
            Console.WriteLine("    Kubernetes Options:");
            Console.WriteLine("      • k3s       - Lightweight production Kubernetes");
            Console.WriteLine("      • minikube  - Development/testing Kubernetes in VM");
            Console.WriteLine();

            // Generate Command
            Console.WriteLine("  generate");
            Console.WriteLine("    Run aspire2kube.ps1 to build migration package");
            Console.WriteLine("    Exports Aspire project images and manifests for Kubernetes deployment");
            Console.WriteLine();
            Console.WriteLine("    Options:");
            Console.WriteLine("      --export-method <value>     Export method: push | tar | skip");
            Console.WriteLine("                                  • push - Push to Docker Hub");
            Console.WriteLine("                                  • tar  - Export as .tar files");
            Console.WriteLine("                                  • skip - Skip image export");
            Console.WriteLine("                                  If omitted, script will prompt.");
            Console.WriteLine();
            Console.WriteLine("      --aspirate-output <path>    Path to aspirate-output folder");
            Console.WriteLine("                                  If omitted, script will prompt.");
            Console.WriteLine();
            Console.WriteLine("      --image <name>              Image name (can be repeated)");
            Console.WriteLine("                                  If omitted, interactive selection.");
            Console.WriteLine();
            Console.WriteLine("      --docker-username <name>    Docker Hub username");
            Console.WriteLine("                                  Required if export-method=push");
            Console.WriteLine();

            // Deploy Command
            Console.WriteLine("  deploy");
            Console.WriteLine("    Deploy Aspire application to Kubernetes cluster");
            Console.WriteLine("    Deploys manifests, imports images, and processes secrets");
            Console.WriteLine();
            Console.WriteLine("    Options:");
            Console.WriteLine("      --target, -t <value>        Kubernetes cluster (k3s, minikube)");
            Console.WriteLine("                                  Default: k3s");
            Console.WriteLine();
            Console.WriteLine("    Prerequisites:");
            Console.WriteLine("      • Must be run from Aspire-Migration folder");
            Console.WriteLine("      • Requires manifests/ directory");
            Console.WriteLine("      • Requires *.tar image files (if using tar export)");
            Console.WriteLine("      • Optional: aspirate-state.json (for secrets)");
            Console.WriteLine();

            // Destroy Command
            Console.WriteLine("  destroy");
            Console.WriteLine("    Cleanup Kubernetes resources");
            Console.WriteLine("    Interactive cleanup with options to select specific resources");
            Console.WriteLine();
            Console.WriteLine("    Options:");
            Console.WriteLine("      --target, -t <value>        Kubernetes cluster (k3s, minikube)");
            Console.WriteLine("                                  Default: k3s");
            Console.WriteLine();
            Console.WriteLine("    Cleanup Modes:");
            Console.WriteLine("      1) Delete ALL resources (quick cleanup)");
            Console.WriteLine("      2) Select specific resource types");
            Console.WriteLine("      3) Preview resources first");
            Console.WriteLine("      4) Minikube-specific operations (if using Minikube)");
            Console.WriteLine();
            Console.WriteLine("    Resource Types:");
            Console.WriteLine("      • Deployments, StatefulSets, DaemonSets");
            Console.WriteLine("      • Services, Ingresses");
            Console.WriteLine("      • ConfigMaps, Secrets");
            Console.WriteLine("      • PersistentVolumeClaims");
            Console.WriteLine("      • Jobs, CronJobs");
            Console.WriteLine("      • Pods");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  USAGE EXAMPLES");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  Basic Workflow:");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # 1. Initialize environment (installs k3s on Ubuntu)");
            Console.WriteLine("    aspire2kube init");
            Console.WriteLine();
            Console.WriteLine("    # 2. Generate migration package");
            Console.WriteLine("    aspire2kube generate");
            Console.WriteLine();
            Console.WriteLine("    # 3. Deploy to Kubernetes");
            Console.WriteLine("    aspire2kube deploy");
            Console.WriteLine();
            Console.WriteLine("    # 4. Cleanup when done");
            Console.WriteLine("    aspire2kube destroy");
            Console.WriteLine();

            Console.WriteLine("  Advanced Init Examples:");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # Auto-detect distribution, install k3s");
            Console.WriteLine("    aspire2kube init");
            Console.WriteLine();
            Console.WriteLine("    # Specific distribution with Minikube");
            Console.WriteLine("    aspire2kube init --distro ubuntu --k8s-type minikube");
            Console.WriteLine("    aspire2kube init -d fedora -k k3s");
            Console.WriteLine();
            Console.WriteLine("    # Rocky/RHEL with k3s");
            Console.WriteLine("    aspire2kube init --distro rocky --k8s-type k3s");
            Console.WriteLine();

            Console.WriteLine("  Generate Examples:");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # Interactive mode (prompts for all options)");
            Console.WriteLine("    aspire2kube generate");
            Console.WriteLine();
            Console.WriteLine("    # Export as tar files");
            Console.WriteLine("    aspire2kube generate --export-method tar");
            Console.WriteLine();
            Console.WriteLine("    # Push to Docker Hub");
            Console.WriteLine("    aspire2kube generate --export-method push --docker-username myuser");
            Console.WriteLine();
            Console.WriteLine("    # Specify aspirate output path");
            Console.WriteLine("    aspire2kube generate --aspirate-output \"C:\\src\\MyApp\\aspirate-output\"");
            Console.WriteLine();
            Console.WriteLine("    # Select specific images");
            Console.WriteLine("    aspire2kube generate --export-method tar \\");
            Console.WriteLine("      --image myapp-api:latest --image myapp-web:latest");
            Console.WriteLine();

            Console.WriteLine("  Deploy Examples:");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # Deploy to k3s (default)");
            Console.WriteLine("    cd Aspire-Migration");
            Console.WriteLine("    aspire2kube deploy");
            Console.WriteLine();
            Console.WriteLine("    # Deploy to Minikube");
            Console.WriteLine("    aspire2kube deploy --target minikube");
            Console.WriteLine();

            Console.WriteLine("  Destroy Examples:");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # Interactive cleanup (k3s)");
            Console.WriteLine("    aspire2kube destroy");
            Console.WriteLine();
            Console.WriteLine("    # Cleanup Minikube resources");
            Console.WriteLine("    aspire2kube destroy --target minikube");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  WORKFLOW GUIDE");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  Step 1: Prerequisites");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    • .NET Aspire application with AppHost project");
            Console.WriteLine("    • Docker installed and running");
            Console.WriteLine("    • Aspirate tool installed (dotnet tool install -g aspirate)");
            Console.WriteLine();

            Console.WriteLine("  Step 2: Generate Aspirate Output");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    cd YourAspireProject");
            Console.WriteLine("    aspirate generate --container-registry docker.io");
            Console.WriteLine("    # This creates aspirate-output/ folder");
            Console.WriteLine();

            Console.WriteLine("  Step 3: Run aspire2kube generate");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    aspire2kube generate --export-method tar \\");
            Console.WriteLine("      --aspirate-output ./aspirate-output");
            Console.WriteLine("    # Creates Aspire-Migration/ folder with manifests and images");
            Console.WriteLine();

            Console.WriteLine("  Step 4: Setup Kubernetes");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # On your target server (Ubuntu/Debian/Fedora/Rocky)");
            Console.WriteLine("    aspire2kube init");
            Console.WriteLine("    # Installs k3s, kubectl, k9s, dashboard, and dependencies");
            Console.WriteLine();

            Console.WriteLine("  Step 5: Transfer and Deploy");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    # Copy Aspire-Migration/ to target server");
            Console.WriteLine("    scp -r Aspire-Migration/ user@server:/home/user/");
            Console.WriteLine();
            Console.WriteLine("    # On target server");
            Console.WriteLine("    cd Aspire-Migration");
            Console.WriteLine("    aspire2kube deploy");
            Console.WriteLine();

            Console.WriteLine("  Step 6: Verify Deployment");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    kubectl get pods");
            Console.WriteLine("    kubectl get services");
            Console.WriteLine("    k9s  # Interactive cluster management");
            Console.WriteLine();

            Console.WriteLine("  Step 7: Cleanup");
            Console.WriteLine("  ──────────────────────────────────────────────────────────────────");
            Console.WriteLine("    aspire2kube destroy");
            Console.WriteLine("    # Interactive selection of resources to delete");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  PLATFORM SUPPORT");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  Windows:");
            Console.WriteLine("    • init     - Supported (PowerShell scripts)");
            Console.WriteLine("    • generate - Fully supported (PowerShell)");
            Console.WriteLine("    • deploy   - Not supported (use WSL or Linux server)");
            Console.WriteLine("    • destroy  - Not supported (use WSL or Linux server)");
            Console.WriteLine();

            Console.WriteLine("  Linux:");
            Console.WriteLine("    • init     - Fully supported (all distributions)");
            Console.WriteLine("    • generate - Not applicable (Windows only)");
            Console.WriteLine("    • deploy   - Fully supported (bash scripts)");
            Console.WriteLine("    • destroy  - Fully supported (bash scripts)");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  INSTALLED COMPONENTS");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  The 'init' command installs:");
            Console.WriteLine("    ✓ Kubernetes (k3s or Minikube)");
            Console.WriteLine("    ✓ kubectl - Kubernetes CLI");
            Console.WriteLine("    ✓ k9s - Terminal UI for Kubernetes");
            Console.WriteLine("    ✓ Kubernetes Dashboard - Web UI");
            Console.WriteLine("    ✓ firewalld - Firewall with k8s ports");
            Console.WriteLine("    ✓ jq - JSON processor");
            Console.WriteLine("    ✓ Python3 + cryptography - Secret decryption");
            Console.WriteLine("    ✓ Docker (Minikube only)");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  TROUBLESHOOTING");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  Common Issues:");
            Console.WriteLine();
            Console.WriteLine("    Q: 'k3s: command not found' after init");
            Console.WriteLine("    A: Restart your terminal or run: source ~/.bashrc");
            Console.WriteLine();
            Console.WriteLine("    Q: Permission denied when running kubectl");
            Console.WriteLine("    A: Ensure KUBECONFIG is set: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml");
            Console.WriteLine();
            Console.WriteLine("    Q: Docker permission denied (Minikube)");
            Console.WriteLine("    A: Log out and back in, or run: newgrp docker");
            Console.WriteLine();
            Console.WriteLine("    Q: Secrets are encrypted, deployment fails");
            Console.WriteLine("    A: The deploy script will automatically decrypt them. Ensure you have");
            Console.WriteLine("       the password from aspirate-state.json metadata.");
            Console.WriteLine();
            Console.WriteLine("    Q: Minikube won't start");
            Console.WriteLine("    A: Try: minikube delete && minikube start");
            Console.WriteLine();
            Console.WriteLine("    Q: SELinux permission errors (Fedora/RHEL)");
            Console.WriteLine("    A: Check: ausearch -m avc -ts recent");
            Console.WriteLine("       k3s is installed with --selinux flag for proper integration");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  USEFUL COMMANDS");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();

            Console.WriteLine("  k3s Management:");
            Console.WriteLine("    systemctl status k3s         - Check k3s status");
            Console.WriteLine("    systemctl restart k3s        - Restart k3s");
            Console.WriteLine("    journalctl -u k3s -f         - View k3s logs");
            Console.WriteLine("    /usr/local/bin/k3s-uninstall.sh  - Uninstall k3s");
            Console.WriteLine();

            Console.WriteLine("  Minikube Management:");
            Console.WriteLine("    minikube status              - Check status");
            Console.WriteLine("    minikube start               - Start cluster");
            Console.WriteLine("    minikube stop                - Stop cluster");
            Console.WriteLine("    minikube delete              - Delete cluster");
            Console.WriteLine("    minikube dashboard           - Open dashboard");
            Console.WriteLine("    minikube service <name>      - Get service URL");
            Console.WriteLine("    minikube addons list         - List addons");
            Console.WriteLine();

            Console.WriteLine("  Kubernetes Management:");
            Console.WriteLine("    kubectl get pods             - List pods");
            Console.WriteLine("    kubectl get services         - List services");
            Console.WriteLine("    kubectl logs <pod>           - View pod logs");
            Console.WriteLine("    kubectl describe pod <pod>   - Pod details");
            Console.WriteLine("    k9s                          - Interactive UI");
            Console.WriteLine();

            Console.WriteLine("  Dashboard Access:");
            Console.WriteLine("    # k3s:");
            Console.WriteLine("    cat ~/k8s-dashboard-token.txt  - Get token");
            Console.WriteLine("    # Open: https://localhost:30443");
            Console.WriteLine();
            Console.WriteLine("    # Minikube:");
            Console.WriteLine("    minikube dashboard");
            Console.WriteLine();

            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine("  MORE INFORMATION");
            Console.WriteLine("═══════════════════════════════════════════════════════════════════");
            Console.WriteLine();
            Console.WriteLine("  Documentation: https://github.com/your-repo/aspire2kube");
            Console.WriteLine("  Issues:        https://github.com/your-repo/aspire2kube/issues");
            Console.WriteLine("  .NET Aspire:   https://learn.microsoft.com/dotnet/aspire");
            Console.WriteLine("  Kubernetes:    https://kubernetes.io/docs");
            Console.WriteLine();

            return 0;
        });

        return help;
    }
}