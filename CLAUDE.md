# CLAUDE.md

Die gemeinsamen Regeln für alle KI-Agenten stehen in `AGENTS.md` und gelten vollständig:

@AGENTS.md

## Zusätzlich für Claude Code

- **MATLAB über MCP:** kurze Läufe mit `evaluate_matlab_code`; die volle Testsuite (~3 min) besser
  im Hintergrund als `matlab -batch "startup_asm; runtests('tests')"` starten und die Ausgabe in
  eine Datei im Scratchpad schreiben.
- In der MCP-Sitzung **nie** `restoredefaultpath` oder `path(pathdef)` aufrufen – das trennt die
  Verbindung zu MATLAB. Veraltete Projektpfade gezielt mit `rmpath` entfernen, dann `startup_asm`.
- Vor `build_library` bzw. `build_examples` geladene Modelle schließen (`bdclose all`); nach
  Umbenennungen von Klassen oder Paketen zusätzlich `rehash`.
- Die Testsuite baut `lib/` neu; das ist gewollt und gehört zur Änderung.
- Umgebung: Windows 11, Git Bash und PowerShell. `python3` war auf diesem Rechner nicht im Pfad –
  Textersetzungen mit dem Edit-Werkzeug oder `sed` erledigen.
- Antworten an den Nutzer auf Deutsch; Ergebnisse mit Testnachweis (Befehl und Ergebnis) melden und
  nicht Ausgeführtes klar als ungeprüft kennzeichnen.
