function daten = drehfeld_daten(x)
%DREHFELD_DATEN Protokoll der Drehfeld-Anzeige in eine Datenstruktur umwandeln.
%   daten = asmbib.drehfeld_daten(x)
%   x: Protokoll [ψα ψβ i2α i2β ϑ] als Struktur mit Zeit (To Workspace "Structure With Time"),
%      Timeseries oder Matrix [t ψα ψβ i2α i2β ϑ]
%   daten: Struktur mit t, psi_h (n×2), i2b (n×2), th_mech (n×1) für asmbib.querschnitt_zustand

if isstruct(x) && isfield(x, 'signals')
    t = x.time(:);  y = x.signals.values;
elseif isa(x, 'timeseries')
    t = x.Time(:);  y = squeeze(x.Data);
else
    t = x(:, 1);  y = x(:, 2:end);
end
y = squeeze(y);                                          % ggf. 5×1×n -> 5×n
if size(y, 1) ~= numel(t), y = y.'; end
[t, iu] = unique(t, 'last');
y = y(iu, :);
daten = struct('t', t, 'psi_h', y(:, 1:2), 'i2b', y(:, 3:4), 'th_mech', y(:, 5));
end
