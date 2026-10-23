// Uninstall.exe - thin double-click launcher / lanciatore sottile a doppio click.
//
// Vivaldi Workspace Tab Mover v1.2.0.
//
// Launches Uninstall-Mod.ps1 (in the SAME folder as this .exe) with Windows PowerShell and
// waits for it. ALL the questions (folder path, language, confirmation) are asked
// by the script itself, in English and Italian: this program contains no logic of
// the mod and no text to translate besides the final prompt below.
// Avvia Uninstall-Mod.ps1 (nella STESSA cartella di questo .exe) con Windows PowerShell e
// attende. TUTTE le domande (percorso, lingua, conferma) le fa lo script, in
// inglese e italiano: qui non c'e' nessuna logica della mod.
//
// Written in C# 5 on purpose: it compiles both with the C# compiler that ships
// with Windows (csc.exe, .NET Framework 4.x - no SDK install needed, see
// README-ricompilazione.md) and with dotnet publish.

using System;
using System.Diagnostics;
using System.IO;

namespace VivaldiWsMod.Uninstaller
{
    internal static class Program
    {
        private static int Main()
        {
            string dir = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(dir, "Uninstall-Mod.ps1");

            if (!File.Exists(script))
            {
                Console.WriteLine();
                Console.WriteLine("ERROR / ERRORE: 'Uninstall-Mod.ps1' not found next to this program / non trovato accanto a questo programma.");
                Console.WriteLine("Keep the .exe in the full package folder / Tieni l'.exe nella cartella del pacchetto completo.");
                return Pause(1);
            }

            var startInfo = new ProcessStartInfo();
            startInfo.FileName = "powershell.exe";
            startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"";
            startInfo.UseShellExecute = false;
            // No stream redirection: the console is shared, so the user sees the
            // script output live (same as running the .bat file).

            int exitCode;
            try
            {
                using (Process process = Process.Start(startInfo))
                {
                    if (process == null)
                    {
                        Console.WriteLine();
                        Console.WriteLine("ERROR / ERRORE: cannot start / impossibile avviare powershell.exe.");
                        return Pause(1);
                    }
                    process.WaitForExit();
                    exitCode = process.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine("ERROR / ERRORE: " + ex.Message);
                return Pause(1);
            }

            return Pause(exitCode);
        }

        private static int Pause(int exitCode)
        {
            Console.WriteLine();
            Console.Write("Press Enter to close / Premi Invio per chiudere...");
            try { Console.ReadLine(); } catch (Exception) { }
            return exitCode;
        }
    }
}