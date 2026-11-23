function E = simuliere(betriebsart, P, opt)
%SIMULIERE Simuliert ein Beispielmodell mit den Parametern P und bereitet die Ergebnisse auf.
%   E = asmapp.simuliere(betriebsart)            Standardwerte (asmapp.standardwerte)
%   E = asmapp.simuliere(betriebsart, P)         P wie asm_standard() bzw. asmapp.standardwerte();
%                                                fehlende Felder erhalten Standardwerte
%   E = asmapp.simuliere(..., 'TimeOut', 300)    Rechenzeitgrenze [s]
%
%   betriebsart  'labor'   Laboraufbau Motor: beispiele/bsp_hochlauf_laststoss.slx
%                'folien'  Folien 16-30 (Stillstand, s = 1): beispiele/bsp_folien16_30_rotorstab.slx
%
%   GUI-freier Rechenkern der Bedienoberfläche ASMApp. Das Modell wird nicht verändert: Parameter
%   gehen nur über Simulink.SimulationInput (setBlockParameter, setModelParameter) an die Masken,
%   zusätzliche Signale (Messbus, Wellenmoment, Effektivwert des Stroms) über
%   SimulationInput.LoggingSpecification. Kein save_system.
%
%   Parameterübergabe (Laboraufbau)
%     Netz             U_L, f1, phasenfolge, t_ein
%     Motor            parametersatz, schaltung; bei "Benutzerdefiniert" zusätzlich R1, L1s, Lh,
%                      R2b, L2sb, p, J_M (bei "Standard" gelten immer die Werte aus asm_standard.m)
%     Messgeräte       Drehzahlmesser ns = 60·f1/p; Strom-, Spannungs-, Leistungsmessung f_mess = f1
%     Last konstant    M_L0 = M_L (last_typ 'konstant'), sonst 0
%     Last Lüfter      M_B = M_L (last_typ 'luefter'), sonst 0; Bezugsdrehzahl n_B = (1 − s_N)·ns
%                      mit s_N = 1 − n_N/ns_N des Standardmotors (Beispielmotor: n_B = 1440 1/min)
%     Laststoß         t_stoss, dM_L (0: kein Laststoß);  Schwungmasse J = J_L
%   Parameterübergabe (Folien): Ideales Drehfeld f1, Bhat, modus_phi2, phi2_fix
%
%   Rückgabe E
%     betriebsart, modell, P (verwendete Werte), solver (Solver, RelTol, MaxStep), dauer_s
%     zeit        Zeitverläufe (Spalten, gemeinsames Zeitraster t):
%                 Labor:  t, n [1/min], Om [rad/s], M [N·m] (Luftspalt), M_W [N·m] (Welle),
%                         M_L [N·m] (Lastkennlinie), s [-] (mit f1), i_abc [A] (Strangströme aus
%                         dem Raumzeiger i1), I_eff [A] (Leiterstrom, Strommessung 3~),
%                         psi_h, i2b, th_mech, phi_el, Bhat
%                 Folien: t, B_perp [T] (Folienzählung wie Rotorstab-Sonde), i_stab [A] (Stab 1/2,
%                         positiv aus der Zeichenebene),
%                         F [N] (Stab 1/2), M_S [N·m], phi_el, theta2 [rad]
%     daten, par  Eingang für asmbib.querschnitt_zustand / asmbib.querschnitt
%     kennlinie   t, n, M, M_L für asmbib.kennlinie_bild (Labor), sonst []
%     stationaer  stationäre ESB-Kennlinie s, n, M mit den aktuellen Werten (Labor), sonst []
%     kennzahlen  Labor: ns, n_end, s_end, M_end, I_eff_end (Mittel der letzten 5 %), M_A, M_K,
%                 s_K, n_K (stationär, ESB), M_max_dyn (größter Betrag des Luftspaltmoments)
%                 Folien: ns, s, ihat_stab, Bhat, phi2_grad, phiZ_grad, M_S_mittel
%     hinweise    Zellenfeld mit Hinweisen zur Plausibilität (z. B. Dreieck an 400 V)
%
%   Quelle der Gleichungen: Hagl, R.: Elektrische Antriebstechnik. Hanser, München 2013;
%   Densborn, Skript "DS-Asynchron-Motor" (DHBW Mannheim). Alle Standardwerte sind Beispielwerte.

arguments
    betriebsart (1,:) char {mustBeMember(betriebsart, {'labor', 'folien'})}
    P struct = struct()
    opt.TimeOut (1,1) double {mustBePositive} = 300
end

[P, hinweise] = vervollstaendige(betriebsart, P);
asmapp.pruefe(P);

load_system('asm_bausteine_lib');
switch betriebsart
    case 'labor',  E = labor(P, opt);
    case 'folien', E = folien(P, opt);
end
E.betriebsart = betriebsart;
E.P = P;
E.hinweise = [hinweise, E.hinweise];
end

%% ========================= Parameter =========================
function [P, hinweise] = vervollstaendige(betriebsart, Pein)
% fehlende Felder ergänzen, Auswahlfelder prüfen, Standardmotor durchsetzen, abgeleitete Größen
P = asmapp.standardwerte(betriebsart);
for f = fieldnames(Pein)'
    if ~strcmp(f{1}, 'info'), P.(f{1}) = Pein.(f{1}); end
end
P.parametersatz = auswahl(P.parametersatz, {'Standard', 'Benutzerdefiniert'}, 'parametersatz');
P.schaltung     = auswahl(P.schaltung, {'Stern', 'Dreieck'}, 'schaltung');
P.phasenfolge   = auswahl(P.phasenfolge, {'L1-L2-L3', 'L1-L3-L2'}, 'phasenfolge');
P.last_typ      = auswahl(P.last_typ, {'konstant', 'luefter'}, 'last_typ');
P.modus_phi2    = auswahl(P.modus_phi2, {'fest', 'Rotorimpedanz'}, 'modus_phi2');

hinweise = {};
S = asm_standard();
if strcmp(P.parametersatz, 'Standard')
    motor = {'R1', 'L1s', 'Lh', 'R2b', 'L2sb', 'p', 'J_M', 'U_N', 'f_N', 'k_R', 'l', 'r', 'N2', 'Bhat_N'};
    abw = motor(cellfun(@(f) ~isequal(P.(f), S.(f)), motor));
    if ~isempty(abw)
        m = sprintf(['Parametersatz "Standard": Motorwerte aus parameter/asm_standard.m verwendet, ' ...
                     'Eingaben für %s ignoriert.'], strjoin(abw, ', '));
        warning('asmapp:standard', '%s', m);
        hinweise{end+1} = m;
    end
    for f = motor, P.(f{1}) = S.(f{1}); end
end
% abgeleitete Größen (Einheiten: ns in 1/min, w1 in rad/s)
P.ns    = 60*P.f1/P.p;
P.w1    = 2*pi*P.f1;
P.N1xi1 = P.p*(P.U_N/sqrt(3)*sqrt(2)/(2*pi*P.f_N))/(2*P.Bhat_N*P.l*P.r);   % wie Maske ASM Standard
P.n_B   = (S.n_N/S.ns)*P.ns;                                             % Bezugsdrehzahl Lüfter
end

function w = auswahl(w, optionen, name)
w = char(w);
if ~any(strcmp(w, optionen))
    error('asmapp:wert', 'Ungültige Auswahl für %s: "%s" (erlaubt: %s).', name, w, strjoin(optionen, ' | '));
end
end

%% ========================= Laboraufbau =========================
function E = labor(P, opt)
m = 'bsp_hochlauf_laststoss';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
in = Simulink.SimulationInput(m);

% Netz
dp = get_param(b('Netz'), 'DialogParameters');
folge = dp.phasenfolge.Enum{1 + strcmp(P.phasenfolge, 'L1-L3-L2')};
in = in.setBlockParameter(b('Netz'), 'U_L', z(P.U_L), b('Netz'), 'f1', z(P.f1), ...
                          b('Netz'), 'phasenfolge', folge, b('Netz'), 't_ein', z(P.t_ein));
% Motor
in = in.setBlockParameter(b('Motor'), 'parametersatz', P.parametersatz, b('Motor'), 'schaltung', P.schaltung);
if strcmp(P.parametersatz, 'Benutzerdefiniert')
    for f = {'R1', 'L1s', 'Lh', 'R2b', 'L2sb', 'p', 'J_M'}
        in = in.setBlockParameter(b('Motor'), f{1}, z(P.(f{1})));
    end
end
% Messgeräte folgen Netzfrequenz und Polpaarzahl
in = in.setBlockParameter(b('Drehzahlmesser'), 'ns', z(P.ns), b('Strommessung'), 'f_mess', z(P.f1), ...
                          b('Leistungsmesser'), 'f_mess', z(P.f1), b('Spannungsmessung'), 'f_mess', z(P.f1));
% Last
konst = strcmp(P.last_typ, 'konstant');
in = in.setBlockParameter(b('Last_konstant'), 'M_L0', z(konst*P.M_L), ...
                          b('Luefter'), 'M_B', z(~konst*P.M_L), b('Luefter'), 'n_B', z(P.n_B), ...
                          b('Laststoss'), 't_stoss', z(P.t_stoss), b('Laststoss'), 'dM_L', z(P.dM_L), ...
                          b('Last_J'), 'J', z(P.J_L));
% Simulation und zusätzliche Protokolle
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut, 'SimscapeLogType', 'none');
ls = Simulink.Simulation.LoggingSpecification;
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Motor')), 1);          % Messbus
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Messwelle')), 1);      % Wellenmoment
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Strommessung')), 2);   % I_eff
in.LoggingSpecification = ls;

[out, E] = rechne(in, m, P);

% Ergebnisse
mess = protokoll(out, b('Motor'));
t = eindeutig(mess.n.Time);
v = @(ts) aufraster(ts, t);
vz = 1 - 2*strcmp(P.phasenfolge, 'L1-L3-L2');          % Drehrichtung des Feldes
Z.t = t;
Z.n = v(mess.n);   Z.Om = v(mess.Om);   Z.M = v(mess.M);
Z.M_W = v(protokoll(out, b('Messwelle')));
Z.I_eff = v(protokoll(out, b('Strommessung')));
Z.s = (vz*P.ns - Z.n)/(vz*P.ns);
i1 = v(mess.i1);  i1 = i1(:,1) + 1j*i1(:,2);  a = exp(2j*pi/3);
Z.i_abc = [real(i1), real(a^2*i1), real(a*i1)];        % Strangströme U, V, W (Stern: = Leiterströme)
Z.psi_h = v(mess.psi_h);  Z.i2b = v(mess.i2b);  Z.th_mech = v(mess.th_mech);
Z.phi_el = v(mess.phi_el);  Z.Bhat = v(mess.Bhat);
% Lastmoment aus den Kennlinien der Lastbausteine (Katalog, geglättete Vorzeichen wie .ssc)
sgn = tanh(Z.Om/0.1);
Z.M_L = strcmp(P.last_typ, 'konstant')*P.M_L*sgn ...
      + strcmp(P.last_typ, 'luefter')*P.M_L*(Z.n/P.n_B).*abs(Z.n/P.n_B) ...
      + P.dM_L*0.5*(1 + tanh((t - P.t_stoss)/0.5e-3)).*sgn;
E.zeit = Z;

E.daten = struct('t', t, 'psi_h', Z.psi_h, 'i2b', Z.i2b, 'th_mech', Z.th_mech);
E.par = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, 'N1xi1', P.N1xi1, ...
               'k1', 1, 'k2', 1 + round(P.N2/(2*P.p)), 'lage1', -pi/2);
E.kennlinie = struct('t', t, 'n', Z.n, 'M', Z.M, 'M_L', Z.M_L);

% stationäre Kennlinie (T-ESB) mit den aktuellen Werten
esb = @(s) asmbib.esb_kennlinie(P, s, 'U', P.U_L, 'f', P.f1, 'Schaltung', P.schaltung);
s_v = linspace(1, 0, 601);
E.stationaer = struct('s', s_v, 'n', vz*P.ns*(1 - s_v), 'M', vz*esb(s_v));
s_f = linspace(1e-4, 1, 20000);
[M_K, iK] = max(esb(s_f));

ib = t >= t(1) + 0.95*(t(end) - t(1));
K.ns = P.ns;
K.n_end = mittel(t(ib), Z.n(ib));
K.s_end = (vz*P.ns - K.n_end)/(vz*P.ns);
K.M_end = mittel(t(ib), Z.M(ib));
K.I_eff_end = mittel(t(ib), Z.I_eff(ib));
K.M_A = esb(1);
K.M_K = M_K;
K.s_K = s_f(iK);
K.n_K = P.ns*(1 - K.s_K);
K.M_max_dyn = max(abs(Z.M));
E.kennzahlen = K;

% Hinweise zur Plausibilität
h = {};
if strcmp(P.schaltung, 'Dreieck') && P.U_L > 1.1*P.U_N/sqrt(3)
    h{end+1} = sprintf(['Dreieckschaltung: Strangspannung %g V statt U_N/√3 = %.0f V – die Wicklung ' ...
                        'liegt an der %.2f-fachen Bemessungs-Strangspannung.'], P.U_L, P.U_N/sqrt(3), P.U_L*sqrt(3)/P.U_N);
end
if abs(P.f1 - P.f_N) > 1e-9
    h{end+1} = sprintf(['Netzfrequenz f1 = %g Hz ≠ Bemessungsfrequenz f_N = %g Hz: Schlupf aus n und f1 ' ...
                        'berechnet (der Messbus-Schlupf s des Motors bezieht sich auf f_N).'], P.f1, P.f_N);
end
if P.dM_L ~= 0 && P.t_stoss >= P.t_end
    h{end+1} = sprintf('Der Laststoß bei t = %g s liegt nach dem Simulationsende t_End = %g s.', P.t_stoss, P.t_end);
end
if K.s_K >= 1 - 1e-3
    h{end+1} = 'Kippschlupf s_K ≥ 1: das Kippmoment liegt nicht im Motorbereich (M_K = M_A).';
end
E.hinweise = h;
end

%% ========================= Folien 16-30 =========================
function E = folien(P, opt)
m = 'bsp_folien16_30_rotorstab';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
dp = get_param(b('Drehfeld'), 'DialogParameters');
modi = dp.modus_phi2.Enum;
modus = modi{find(contains(modi, P.modus_phi2), 1)};   % 'fest' | 'aus Rotorimpedanz (...)'
in = Simulink.SimulationInput(m);
in = in.setBlockParameter(b('Drehfeld'), 'f1', z(P.f1), b('Drehfeld'), 'Bhat', z(P.Bhat), ...
                          b('Drehfeld'), 'modus_phi2', modus, b('Drehfeld'), 'phi2_fix', z(P.phi2_fix));
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut);
[out, E] = rechne(in, m, P);

D = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
w = @(blk, n) str2double(get_param(b(blk), n));        % Geometrie wie in Sonde und Anzeige des Modells
par = struct('p', w('Anzeige', 'p'), 'N2', w('Anzeige', 'N2'), 'l', w('Anzeige', 'l'), ...
             'r', w('Anzeige', 'r'), 'N1xi1', w('Anzeige', 'N1xi1'), ...
             'k1', w('Sonde', 'k1'), 'k2', w('Sonde', 'k2'), 'lage1', w('Anzeige', 'lage1')*pi/180);
R = asmbib.querschnitt_zustand(D, par, D.t);
ks = [par.k1 par.k2];
% Folienzählung wie Rotorstab-Sonde ("wie Folien"): Strom aus der Zeichenebene positiv, die
% Schleifennormale dreht sich mit, B⊥ = −B̂·sin(γ_1 − φ_el) (SPEC Abschnitt 13)
E.zeit = struct('t', D.t, 'B_perp', -R.B_perp, 'i_stab', R.i_folie(:, ks), 'F', R.F(:, ks), ...
                'M_S', R.M_S, 'phi_el', R.phi_el, 'theta2', R.theta2);
E.daten = D;
E.par = par;
E.kennlinie = [];
E.stationaer = [];

s = str2double(get_param(b('Drehfeld'), 's'));
T2 = 1/(abs(s)*P.f1);                                  % Periode des Feldes relativ zum Rotor
ib = D.t >= D.t(end) - min(T2, D.t(end) - D.t(1));
K.ns = 60*P.f1/par.p;
K.s = s;
K.ihat_stab = max(abs(R.i_folie(:)));
K.Bhat = mean(R.Bhat);
K.phi2_grad = rad2deg(mittel(D.t, R.phi2));
K.phiZ_grad = K.phi2_grad - 90;
K.M_S_mittel = mittel(D.t(ib), R.M_S(ib));
E.kennzahlen = K;
E.hinweise = {};
if P.t_end < T2
    E.hinweise{end+1} = sprintf('t_End = %g s ist kürzer als eine Feldumdrehung (%g s).', P.t_end, T2);
end
end

%% ========================= Hilfsfunktionen =========================
function [out, E] = rechne(in, m, P)
t0 = tic;
out = sim(in);
E.dauer_s = toc(t0);
if isprop(out, 'ErrorMessage') && ~isempty(out.ErrorMessage)
    error('asmapp:simulation', '%s', out.ErrorMessage);
end
if out.tout(end) < P.t_end*(1 - 1e-9)
    error('asmapp:simulation', 'Simulation nach %.0f s abgebrochen bei t = %.4g s (Zeitgrenze TimeOut).', ...
          E.dauer_s, out.tout(end));
end
E.modell = m;
E.solver = struct('Solver', get_param(m, 'Solver'), 'RelTol', str2double(get_param(m, 'RelTol')), ...
                  'MaxStep', str2double(get_param(m, 'MaxStep')));
end

function x = protokoll(out, blockpfad)
% protokolliertes Signal des Ausgangs von blockpfad (LoggingSpecification) aus out.logsout
L = out.logsout;
for k = 1:L.numElements
    if strcmp(L{k}.BlockPath.getBlock(1), blockpfad)
        x = L{k}.Values;
        return;
    end
end
error('asmapp:protokoll', 'Kein Protokoll für %s.', blockpfad);
end

function t = eindeutig(t)
t = unique(t(:));
end

function y = aufraster(ts, t)
% Timeseries auf das Zeitraster t (doppelte Zeitpunkte an Ereignissen: letzter Wert)
d = squeeze(ts.Data);
if size(d, 1) ~= numel(ts.Time), d = d.'; end
[tt, iu] = unique(ts.Time(:), 'last');
y = interp1(tt, d(iu, :), t, 'linear', 'extrap');
end

function m = mittel(t, y)
% zeitlicher Mittelwert (ungleichmäßiges Zeitraster)
if numel(t) < 2 || t(end) == t(1), m = mean(y); return; end
m = trapz(t, y)/(t(end) - t(1));
end
