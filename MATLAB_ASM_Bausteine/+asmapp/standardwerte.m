function P = standardwerte(betriebsart)
%STANDARDWERTE Vollständige Parameterstruktur für asmapp.simuliere bzw. die Bedienoberfläche.
%   P = asmapp.standardwerte()            Betriebsart 'labor'
%   P = asmapp.standardwerte(betriebsart) 'labor' | 'folien'
%
%   Grundlage ist parameter/asm_standard.m (Motor, alle Werte Beispielwerte). Ergänzt werden
%   Netz, Last und Simulation mit den Werten der Beispielmodelle
%   beispiele/bsp_hochlauf_laststoss.slx bzw. beispiele/bsp_folien16_30_rotorstab.slx.
%
%   Zusätzliche Felder (Einheiten wie Konventionen; Code-Bezeichner ohne Umlaute)
%     parametersatz  'Standard' | 'Benutzerdefiniert'      Motor
%     schaltung      'Stern' | 'Dreieck'                   Motor (Klemmbrett)
%     U_L   [V]      Leiterspannung des Netzes (Effektivwert)
%     f1    [Hz]     Netzfrequenz (Folien: Frequenz des idealen Drehfelds)
%     phasenfolge    'L1-L2-L3' (Rechtsdrehfeld) | 'L1-L3-L2' (Linksdrehfeld)
%     t_ein [s]      Einschaltzeitpunkt
%     last_typ       'konstant' | 'luefter'                Grundlast
%     M_L   [N·m]    Grundlast (konstant: M_L0; Lüfter: Moment bei der Bezugsdrehzahl n_B)
%     dM_L  [N·m]    Höhe des Laststoßes (0: kein Laststoß)
%     t_stoss [s]    Zeitpunkt des Laststoßes
%     J_L   [kg·m²]  Zusatzträgheit der Last (Schwungmasse)
%     t_end [s]      Simulationsdauer
%     Bhat  [T]      Amplitude der Luftspaltflussdichte (nur Folien)
%     modus_phi2     'fest' | 'Rotorimpedanz'              (nur Folien)
%     phi2_fix [°]   fester Versatzwinkel φ2              (nur Folien)

arguments
    betriebsart (1,:) char {mustBeMember(betriebsart, {'labor', 'folien'})} = 'labor'
end

P = asm_standard();
P = rmfield(P, 'info');
P.parametersatz = 'Standard';
P.schaltung     = 'Stern';
P.U_L           = P.U_N;
P.f1            = P.f_N;
P.phasenfolge   = 'L1-L2-L3';
P.t_ein         = 0;
P.last_typ      = 'luefter';
P.M_L           = P.M_N;          % Lüfter: M_L = M_N bei n_B = n_N (wie Beispielmodell)
P.dM_L          = 0.3*P.M_N;      % Laststoß 0,3·M_N bei t = 1 s (wie Beispielmodell)
P.t_stoss       = 1;
P.J_L           = 0.01;
P.Bhat          = P.Bhat_N;
P.modus_phi2    = 'fest';
P.phi2_fix      = 90;
if strcmp(betriebsart, 'labor')
    P.t_end = 2;
else
    P.t_end = 0.04;               % zwei Feldumdrehungen bei 50 Hz, Rotor steht
end
end
