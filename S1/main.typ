#import "@local/templat-projektarbeit:0.1.22": *
#import "Zusatz/acronyms.typ": acronyms

#let titel = "Simulation des Drehstrom-Asynchronmotors in MATLAB"

#show: supercharged-dhbw.with(
  title: titel,
  type-of-thesis: "Seminararbeit",
  authors: (
    (name: "Fredrik Schall", student-id: "1194924", course: "TEIT24EE1", course-of-studies: "Elektro- und Informationstechnik"),
  ),
  acronyms: acronyms, // displays the acronyms defined in the acronyms dictionary
  at-university: true, // if true the company name on the title page and the confidentiality statement are hidden
  bibliography: bibliography("Zusatz/zotero.bib"),
  city: "Mannheim", // TODO: Ort der Unterschrift (steht in der Selbstständigkeitserklärung)
  date: datetime(year: 2026, month: 11, day: 25), // TODO: Abgabedatum (Titelblatt und Selbstständigkeitserklärung)
  language: "de", // en, de
  ki-anmerkung-content: include "Anmerkung KI.typ",
  // Wortlaut nach DHBW-Leitlinien Technik (10.11.2025), Kap. 4.4, inkl. Zusatz zur KI-Nutzung
  declaration-of-authorship-content: [
    #set par(justify: true)
    Ich versichere hiermit, dass ich die vorliegende Arbeit mit dem Thema:
    #v(1em)
    #align(center, strong(titel))
    #v(1em)
    selbstständig verfasst und keine anderen als die angegebenen Quellen und Hilfsmittel verwendet habe und diese Arbeit bei keiner anderen Prüfung mit gleichem oder vergleichbarem Inhalt vorgelegt habe und diese bislang nicht veröffentlicht wurde.

    Ich habe bei der Erstellung der Arbeit KI-Werkzeuge eingesetzt. Dies habe ich an den entsprechenden Stellen der Arbeit kenntlich gemacht.
  ],
  // Vorwort einfügen (optional):
  foreword: include "Texte/Vorwort.typ",
  supervisor: (university: "Dipl.-Ing. Michael Densborn"),
  university: "Duale Hochschule Baden-Württemberg",
  university-location: "Mannheim",
  university-short: "DHBW",
  // Schriftart anpassen (z.B. "New Computer Modern"):
  font: "Liberation Serif",
  // Firmenlogo einfügen (Datei z.B. in assets/ ablegen):
  // logo-right: image("assets/firmenlogo.svg"),
  // for more options check the package documentation (https://typst.app/universe/package/supercharged-dhbw)
)


#include "Texte/lorem_ipsum.typ"

