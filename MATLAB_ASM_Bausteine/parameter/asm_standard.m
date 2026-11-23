function P = asm_standard()
%ASM_STANDARD Standardparametersatz für den Baustein "ASM Standard".
%   P = asm_standard() liefert eine Struktur mit allen Parametern in SI-Einheiten
%   (Drehzahlen in 1/min). P.info enthält zu jedem Feld Einheit und Herkunft.
%
%   ALLE ZAHLENWERTE SIND BEISPIELWERTE (fiktiver 4-kW-Normmotor, 4-polig) ODER
%   AUS DIESEN ABGELEITET. ES SIND KEINE DATENBLATT- ODER MESSWERTE.
%
%   Herkunft: Ersatzschaltbild (ESB) aus init_asm_referenz.m des Prototyps (Teil C).
%   Die ESB-Werte sind so bestimmt, dass das stationäre Kippmoment MK = 2,7*MN bei
%   sK = 0,2 liegt (siehe doku/SPEC.md, Abschnitt 3.3 und 4.5).
%
%   Notation wie Folien: Index 1 = Stator, 2 = Rotor; Endung s = Streuung (sigma),
%   Endung b = auf den Stator bezogen (Strich). Quelle der Gleichungen:
%   Hagl, R.: Elektrische Antriebstechnik. Hanser, München 2013.

% Tabelle: Feld | Wert | Einheit | Herkunft
T = {
    'U_N',    400,        'V',          'Beispielwert, Leiterspannung (Stern)'
    'f_N',    50,         'Hz',         'Beispielwert'
    'p',      2,          '-',          'Beispielwert'
    'P_N',    4e3,        'W',          'Beispielwert (nur Information)'
    'n_N',    1440,       '1/min',      'Beispielwert (nur Information)'
    'M_N',    26.5,       'N*m',        'Beispielwert (nur Information)'
    'R1',     0.5,        'Ohm',        'Annahme (Prototyp Teil C, Rs)'
    'L1s',    9.902e-3,   'H',          'abgeleitet (MK-Abgleich, Prototyp Teil C, Lls)'
    'Lh',     0.25,       'H',          'Annahme (Prototyp Teil C, Lm)'
    'R2b',    1.225,      'Ohm',        'abgeleitet (sK-Abgleich, Prototyp Teil C, Rr)'
    'L2sb',   9.902e-3,   'H',          'abgeleitet (= L1s, Prototyp Teil C, Llr)'
    'J_M',    0.012,      'kg*m^2',     'Beispielwert'
    'k_R',    0,          'N*m*s/rad',  'Annahme (keine Reibung, wie Prototyp)'
    'l',     0.15,       'm',          'Beispielwert (wirksame Stablänge)'
    'r',      0.06,       'm',          'Beispielwert (Radius der Stabmitte)'
    'N2',     28,         '-',          'Annahme (Anzahl Rotorstäbe)'
    'Bhat_N', 0.8,        'T',          'Beispielwert (Luftspaltflussdichte im Bemessungspunkt)'
    };

for k = 1:size(T, 1)
    P.(T{k,1}) = T{k,2};
    P.info.(T{k,1}) = struct('Einheit', T{k,3}, 'Herkunft', T{k,4});
end

% Abgeleitete Größen (nur zur Information)
P.ns    = 60*P.f_N/P.p;                           % Synchrondrehzahl          [1/min]
P.w1    = 2*pi*P.f_N;                             % Statorkreisfrequenz       [rad/s]
psi_h_N = P.U_N/sqrt(3)*sqrt(2)/P.w1;             % Näherung |psi_h| ~ U1,Str*sqrt(2)/w1 [Vs]
P.N1xi1 = P.p*psi_h_N/(2*P.Bhat_N*P.l*P.r);       % wirksame Windungszahl     [-]
P.info.ns    = struct('Einheit', '1/min', 'Herkunft', 'abgeleitet: ns = 60*f_N/p');
P.info.w1    = struct('Einheit', 'rad/s', 'Herkunft', 'abgeleitet: w1 = 2*pi*f_N');
P.info.N1xi1 = struct('Einheit', '-', ...
    'Herkunft', 'abgeleitet: N1xi1 = p*|psi_h|/(2*Bhat_N*l*r), |psi_h| ~ U1,Str*sqrt(2)/w1');
end
