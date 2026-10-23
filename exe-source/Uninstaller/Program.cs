// Uninstall.exe - punto di ingresso a doppio click per rimuovere il mod
// "Sposta nel Workspace". Stessa logica di Install.exe (vedi commenti li'),
// applicata a Uninstall-Mod.ps1. La domanda di conferma "Continuare? (S/N)"
// resta gestita interamente dallo script PowerShell invariato: questo
// programma non la duplica, si limita a condividere la console col processo
// figlio cosi' il prompt interattivo funziona esattamente come da Uninstall.bat.

using System.Diagnostics;

namespace VivaldiWsMod.Uninstaller;

internal static class Program
{
    private static int Main()
    {
        Console.WriteLine("============================================================");
        Console.WriteLine("  Disinstaller Mod \"Sposta nel Workspace\" - Vivaldi");
        Console.WriteLine("============================================================");
        Console.WriteLine();

        Console.Write("Percorso cartella Application di Vivaldi (es. H:\\Vivaldi Standalone\\Application): ");
        string? vivaldiAppRoot = Console.ReadLine();

        if (string.IsNullOrWhiteSpace(vivaldiAppRoot))
        {
            Console.WriteLine();
            Console.WriteLine("ERRORE: nessun percorso inserito. Disinstallazione annullata.");
            return Pause(1);
        }

        string exeDir = AppContext.BaseDirectory;
        string engineScript = Path.Combine(exeDir, "Uninstall-Mod.ps1");

        if (!File.Exists(engineScript))
        {
            Console.WriteLine();
            Console.WriteLine("ERRORE: 'Uninstall-Mod.ps1' non trovato accanto a Uninstall.exe.");
            Console.WriteLine("Assicurati che Uninstall.exe sia nella cartella del pacchetto completo.");
            return Pause(1);
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(engineScript);
        startInfo.ArgumentList.Add("-VivaldiAppRoot");
        startInfo.ArgumentList.Add(vivaldiAppRoot);

        int exitCode;
        try
        {
            using Process? process = Process.Start(startInfo);
            if (process is null)
            {
                Console.WriteLine();
                Console.WriteLine("ERRORE: impossibile avviare powershell.exe.");
                return Pause(1);
            }

            process.WaitForExit();
            exitCode = process.ExitCode;
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Console.WriteLine("ERRORE IMPREVISTO: " + ex.Message);
            return Pause(1);
        }

        return Pause(exitCode);
    }

    private static int Pause(int exitCode)
    {
        Console.WriteLine();
        Console.Write("Premi Invio per chiudere...");
        Console.ReadLine();
        return exitCode;
    }
}
