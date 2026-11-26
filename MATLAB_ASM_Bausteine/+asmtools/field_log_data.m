function data = field_log_data(x)
%FIELD_LOG_DATA Convert the log of the field display into a data struct.
%   data = asmtools.field_log_data(x)
%   x: log [psi_alpha psi_beta i2_alpha i2_beta th] as struct with time (To Workspace
%      "Structure With Time"), timeseries or matrix [t psi_alpha psi_beta i2_alpha i2_beta th]
%   data: struct with t, psi_h (n x 2), i2b (n x 2), th_mech (n x 1) for asmtools.cross_section_state

if isstruct(x) && isfield(x, 'signals')
    t = x.time(:);  y = x.signals.values;
elseif isa(x, 'timeseries')
    t = x.Time(:);  y = squeeze(x.Data);
else
    t = x(:, 1);  y = x(:, 2:end);
end
y = squeeze(y);                                          % 5x1xn -> 5xn if needed
if size(y, 1) ~= numel(t), y = y.'; end
[t, iu] = unique(t, 'last');
y = y(iu, :);
data = struct('t', t, 'psi_h', y(:, 1:2), 'i2b', y(:, 3:4), 'th_mech', y(:, 5));
end
