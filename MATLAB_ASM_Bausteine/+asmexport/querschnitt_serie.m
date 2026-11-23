function dateien = querschnitt_serie(daten, par, opt)
%QUERSCHNITT_SERIE Einzelbilder des Rotorquerschnitts bei festen Feldwinkeln (Folien 18-30).
%   dateien = asmexport.querschnitt_serie(daten, par)
%   dateien = asmexport.querschnitt_serie(daten, par, 'Winkel', 0:30:360, 'Name', 'folie', ...
%                                         'Nummern', 18:30, 'Ordner', ordner)
%
%   daten    Struktur t, psi_h, i2b, th_mech (asmbib.drehfeld_daten), mindestens eine volle
%            Umdrehung des Feldes relativ zum Rotor
%   par      p, N2, l, r, N1xi1, k1, k2, lage1 (siehe asmbib.rotorstab)
%   Winkel   Feldwinkel relativ zum Rotor θ2 in Grad (mathematisch positiv; in der Folienansicht
%            dreht das Feld im Uhrzeigersinn, 0:30:360 entspricht den Folien 18-30)
%   Weitere Optionen: Darstellungsoptionen von asmbib.querschnitt, Ordner, Formate (folienbild)
%   Bilder aus der letzten vollen Feldumdrehung. Rückgabe: Dateinamen.

arguments
    daten struct
    par struct
    opt.Winkel (1,:) double = 0:30:360
    opt.Name {mustBeTextScalar} = 'folie'
    opt.Nummern (1,:) double = []
    opt.Ordner {mustBeTextScalar} = asmexport.zielordner()
    opt.Formate (1,:) string = ["png" "svg"]
    opt.orientierung (1,:) char = 'folien'
    opt.ansicht (1,:) char = 'rotorfest'
    opt.zerlegung (1,1) logical = true
    opt.aenderung (1,1) logical = true
    opt.kraft (1,1) logical = true
    opt.alle (1,1) logical = true
end
if isempty(opt.Nummern), opt.Nummern = 18 + (0:numel(opt.Winkel) - 1); end

% Feldwinkel relativ zum Rotor über der Zeit, letzte volle Umdrehung
tg = linspace(daten.t(1), daten.t(end), 20*numel(daten.t))';
Zg = asmbib.querschnitt_zustand(daten, par, tg);
thu = unwrap(Zg.theta2);
if thu(end) - thu(1) < 2*pi
    error('asmexport:serie', 'Die Daten enthalten keine volle Feldumdrehung relativ zum Rotor.');
end
basis = 2*pi*floor((thu(end) - 2*pi)/(2*pi));
basis = max(basis, 2*pi*ceil(thu(1)/(2*pi)));
[thu_e, iu] = unique(thu);
tz = interp1(thu_e, tg(iu), basis + deg2rad(opt.Winkel));

Z = asmbib.querschnitt_zustand(daten, par, tz);
dopt = struct('orientierung', opt.orientierung, 'ansicht', opt.ansicht, 'zerlegung', opt.zerlegung, ...
              'aenderung', opt.aenderung, 'kraft', opt.kraft, 'alle', opt.alle, ...
              'i_max', max(abs(Zg.i_folie(:))), 'F_max', max(max(abs(Zg.F(:, [par.k1 par.k2])))), ...
              'dB_max', max(abs(Zg.dB_perp)));
dateien = {};
for k = 1:numel(tz)
    f = figure('Visible', 'off', 'Color', 'w');
    ax = axes(f);
    asmbib.querschnitt(ax, Z, k, par, dopt);
    title(ax, sprintf('Feldwinkel relativ zum Rotor θ_2 = %g°   (Folie %d)', opt.Winkel(k), opt.Nummern(k)), ...
          'FontWeight', 'normal', 'Color', 'k');
    d = asmexport.folienbild(f, sprintf('%s%02d', opt.Name, opt.Nummern(k)), ...
                             'Ordner', opt.Ordner, 'Formate', opt.Formate);
    dateien = [dateien, d]; %#ok<AGROW>
    close(f);
end
end
