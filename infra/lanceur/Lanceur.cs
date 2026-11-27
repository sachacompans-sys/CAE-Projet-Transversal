// UrbanWatt.exe : petit lanceur qui exécute lancer_urbanwatt.bat situé dans le même dossier.
// Compilation (Windows, sans rien installer) :
//   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /out:UrbanWatt.exe infra\lanceur\Lanceur.cs
using System;
using System.Diagnostics;
using System.IO;

class Lanceur
{
    static int Main()
    {
        string dossier = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(dossier, "lancer_urbanwatt.bat");
        if (!File.Exists(script))
        {
            Console.WriteLine("lancer_urbanwatt.bat est introuvable : place UrbanWatt.exe à la racine du dépôt.");
            Console.ReadKey();
            return 1;
        }
        var demarrage = new ProcessStartInfo("cmd.exe", "/c \"\"" + script + "\"\"")
        {
            WorkingDirectory = dossier,
            UseShellExecute = false,
        };
        Process.Start(demarrage).WaitForExit();
        return 0;
    }
}
