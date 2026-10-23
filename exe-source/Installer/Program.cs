// Install.exe - punto di ingresso a doppio click per il mod "Sposta nel Workspace".
//
// Cosa fa, in ordine:
//   1. Stampa un'intestazione e chiede all'utente il percorso della cartella
//      "Application" della sua installazione Vivaldi (stessa domanda che fa
//      gia' Install.bat).
//   2. Cerca "Install-Mod.ps1" nella STESSA cartella in cui si trova questo
//      .exe (il motore di installazione vero e proprio: script PowerShell
//      esistente, non toccato/modificato da questo programma).
//   3. Lo lancia con "powershell.exe -File Install-Mod.ps1 -VivaldiAppRoot <percorso>",
//      lasciando la console condivisa cosi' l'utente vede in diretta l'output
//      dello script (identico a quello che si vede lanciando Install.bat).
//   4. Attende la fine, mostra il codice di uscita e aspetta un tasto prima
//      di chiudersi, cosi' la finestra non sparisce subito e l'utente puo'
//      leggere l'esito.
//
// Nota per chi mantiene questo codice: la logica di installazione VERA vive
// tutta in Install-Mod.ps1 (PowerShell). Questo eseguibile e' solo un
// lanciatore nativo che sostituisce Install.bat con un'esperienza a doppio
// click piu' "da programma" (icona propria, nessuna finestra nera generica
// del prompt dei comandi in stile batch); non duplica e non ripete nessuna
// delle regole di business del mod.

using System.Diagnostics;

namespace VivaldiWsMod.Installer;

internal static class Program
{
    private static int Main()
    {
        Console.WriteLine("============================================================");
        Console.WriteLine("  Installer Mod \"Sposta nel Workspace\" - Vivaldi");
        Console.WriteLine("============================================================");
        Console.WriteLine();

        Console.Write("Percorso cartella Application di Vivaldi (es. H:\\Vivaldi Standalone\\Application): ");
        string? vivaldiAppRoot = Console.ReadLine();

        if (string.IsNullOrWhiteSpace(vivaldiAppRoot))
        {
            Console.WriteLine();
            Console.WriteLine("ERRORE: nessun percorso inserito. Installazione annullata.");
            return Pause(1);
        }

        // Cartella in cui si trova questo eseguibile: e' li' che deve trovarsi
        // anche Install-Mod.ps1 (pacchetto completo, non spostato/spezzato).
        string exeDir = AppContext.BaseDirectory;
        string engineScript = Path.Combine(exeDir, "Install-Mod.ps1");

        if (!File.Exists(engineScript))
        {
            Console.WriteLine();
            Console.WriteLine("ERRORE: 'Install-Mod.ps1' non trovato accanto a Install.exe.");
            Console.WriteLine("Assicurati che Install.exe sia nella cartella del pacchetto completo");
            Console.WriteLine("(insieme a Install-Mod.ps1 e alla sottocartella 'payload').");
            return Pause(1);
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            // Nessuna redirezione degli stream: la console resta condivisa con
            // il processo figlio, esattamente come quando Install.bat lancia
            // powershell.exe direttamente. L'utente vede l'output in diretta.
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
