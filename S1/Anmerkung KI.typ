#figure(
  caption: [Übersicht über die verwendeten KI-basierten Werkzeuge],
  table(
    columns: (1.1fr, 4fr),
    inset: 10pt,
    align: (left + horizon, left + horizon),
    fill: (_, y) => if y == 0 { luma(200) } else { white },

    table.header([*Werkzeug*], [*Beschreibung der Nutzung*]),

    [Claude Code],
    [
      - Unterstützung bei der Erstellung des MATLAB/Simulink-Programms einschließlich Beispielen, Tests, Dokumentation und exportierten Abbildungen (Ordner `MATLAB_ASM_Bausteine`)
      - Anpassung der Typst-Dokumentvorlage sowie Recherche der formalen Vorgaben der DHBW (gesamt)
    ],

    // Nur einkommentieren, was für diese Arbeit wirklich genutzt wurde,
    // und möglichst das betroffene Kapitel ergänzen:
    // [Copilot],             [Korrektur- und Formulierungshilfe (gesamt)],
    // [Gemini],              [Recherche von allgemeinen Informationen (Kapitel X)],
    // [Google Scholar Labs], [Recherche von Fachtexten (Kapitel X)],
  ),
) <KI>
