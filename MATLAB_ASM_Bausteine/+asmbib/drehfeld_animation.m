function fig = drehfeld_animation(daten, par, opt)
%DREHFELD_ANIMATION Animation des Rotorquerschnitts aus protokollierten Modellgrößen.
%   fig = asmbib.drehfeld_animation(daten, par)
%   fig = asmbib.drehfeld_animation(daten, par, 'Zeitlupe', 0.02, 'Abspielen', true, ...)
%   fig = asmbib.drehfeld_animation(blk)        aus dem Baustein "Drehfeld-Anzeige" (Maskenknopf):
%                                               Daten aus out.drehfeld_anzeige im Base Workspace
%
%   daten  Struktur t, psi_h, i2b, th_mech (asmbib.drehfeld_daten)
%   par    p, N2, l, r, N1xi1, k1, k2, lage1
%   Optionen: Zeitlupe (Simulationszeit je Sekunde Abspielzeit, Standard 0,02), Abspielen
%   (false: nur erstes Bild), T (Zeitbereich [t0 t1]), sowie die Darstellungsoptionen von
%   asmbib.querschnitt (orientierung, ansicht, zerlegung, aenderung, kraft, alle).

arguments
    daten
    par struct = struct()
    opt.Zeitlupe (1,1) double {mustBePositive} = 0.02
    opt.Abspielen (1,1) logical = true
    opt.T double = []
    opt.orientierung (1,:) char = 'folien'
    opt.ansicht (1,:) char = 'rotorfest'
    opt.zerlegung (1,1) logical = true
    opt.aenderung (1,1) logical = true
    opt.kraft (1,1) logical = true
    opt.alle (1,1) logical = true
end

if ischar(daten) || isstring(daten)                         % Aufruf aus dem Maskenknopf
    [daten, par, opt] = aus_baustein(char(daten), opt);
end
if isempty(opt.T), opt.T = [daten.t(1), daten.t(end)]; end

fps = 25;
tt  = opt.T(1):opt.Zeitlupe/fps:opt.T(2);
Z   = asmbib.querschnitt_zustand(daten, par, tt);
dopt = rmfield(opt, {'Zeitlupe', 'Abspielen', 'T'});
dopt.i_max  = max(abs(Z.i_folie(:)));                         % feste Skalierung über die Animation
dopt.F_max  = max(max(abs(Z.F(:, [par.k1 par.k2]))));
dopt.dB_max = max(abs(Z.dB_perp));

fig = figure('Name', 'Drehfeld-Anzeige: Rotorquerschnitt', 'NumberTitle', 'off', 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig);
for k = 1:numel(tt)
    if ~isgraphics(fig), return; end
    asmbib.querschnitt(ax, Z, k, par, dopt);
    drawnow;
    if ~opt.Abspielen, return; end
    pause(1/fps);
end
end

function [daten, par, opt] = aus_baustein(blk, opt)
% Parameter aus der Maske, Daten aus out.drehfeld_anzeige (Base Workspace)
if ~evalin('base', 'exist(''out'', ''var'')')
    error('asmbib:anzeige', 'Keine Simulationsdaten: zuerst simulieren (Ergebnis in "out").');
end
out = evalin('base', 'out');
daten = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
w = get_param(blk, 'MaskWSVariables');
v = @(n) w(strcmp({w.Name}, n)).Value;
par = struct('p', v('p'), 'N2', v('N2'), 'l', v('l'), 'r', v('r'), 'N1xi1', v('N1xi1'), ...
             'k1', 1, 'k2', 1 + v('N2')/(2*v('p')), 'lage1', v('lage1')*pi/180);
ans_ = {'rotorfest', 'statorfest'};  opt.ansicht = ans_{v('ansicht')};
ori = {'folien', 'mathematisch'};    opt.orientierung = ori{v('orientierung')};
opt.zerlegung = logical(v('zerlegung'));  opt.aenderung = logical(v('aenderungsvektor'));
opt.kraft = logical(v('kraftpfeile'));    opt.alle = logical(v('alle_staebe'));
opt.Zeitlupe = v('zeitlupe');
end
