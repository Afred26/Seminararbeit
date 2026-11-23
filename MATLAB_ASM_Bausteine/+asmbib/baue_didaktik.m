function ok = baue_didaktik(blk, b)
%BAUE_DIDAKTIK Inhalt der Didaktik-Bausteine und der Leiterschleife (aufgerufen von build_library).
%   ok = asmbib.baue_didaktik(blk, b)  baut den Inhalt des Subsystems blk für Katalogeintrag b
%   und liefert true; für andere Bausteine false (dann baut build_library einen Platzhalter).
%   Rechenkerne: MATLAB-System-Blöcke (interpretiert, kein C-Compiler nötig) mit den
%   System-Objekten asmbib.IdealesDrehfeld, asmbib.SondeRotorstab, asmbib.Leiterschleife.
%   Ein- und Ausgänge heißen wie im Katalog; Parameter sind die Maskenvariablen.

ok = true;
switch b.id
    case 'ideales_drehfeld'
        add_block('simulink/Sources/Clock', [blk '/Zeit'], 'Position', [40 100 70 130]);
        sys = system_block(blk, 'IdealesDrehfeld', 'asmbib.IdealesDrehfeld', ...
            {'Bhat', 'f1', 'p', 's', 'l', 'r', 'N1xi1', 'N2', 'R2_S', 'L2s_S', 'phi2_fix'}, ...
            {'modus', 'modus_phi2'});
        add_line(blk, 'Zeit/1', 'IdealesDrehfeld/1');
        ausgaenge(blk, b, sys, 1:5);

    case 'rotorstab_sonde'
        eingaenge(blk, b);
        sys = system_block(blk, 'Sonde', 'asmbib.SondeRotorstab', {'p', 'N2', 'l', 'r', 'N1xi1', 'k1', 'k2'}, ...
            {'lage1', 'lage1*pi/180', 'folie', 'darstellung == 1'});
        for k = 1:3, add_line(blk, sprintf('%s/1', b.ein(k).name), sprintf('Sonde/%d', k)); end
        % Ausgänge: 6 direkt, dB_perp über Derivative aus B_perp, dann sgn_i, phi2, M_sum
        add_block('simulink/Continuous/Derivative', [blk '/dBdt'], 'Position', [520 300 550 330]);
        add_line(blk, 'Sonde/6', 'dBdt/1');
        quelle = {'Sonde/1', 'Sonde/2', 'Sonde/3', 'Sonde/4', 'Sonde/5', 'Sonde/6', 'dBdt/1', ...
                  'Sonde/7', 'Sonde/8', 'Sonde/9'};
        outports(blk, b, quelle);

    case 'drehfeld_anzeige'
        eingaenge(blk, b);
        add_block('simulink/Signal Routing/Mux', [blk '/Mux'], 'Inputs', '[2 2 1]', 'Position', [200 40 205 160]);
        for k = 1:3, add_line(blk, sprintf('%s/1', b.ein(k).name), sprintf('Mux/%d', k)); end
        add_block('simulink/Sinks/To Workspace', [blk '/Protokoll'], 'Position', [260 85 360 115], ...
            'VariableName', 'drehfeld_anzeige', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
        add_line(blk, 'Mux/1', 'Protokoll/1');

    case 'spulenfelder'
        eingaenge(blk, b);
        c = 'p*Lh/(2*N1xi1*l*r)';                            % B̂ je A Raumzeigerstrom
        add_block('simulink/Math Operations/Gain', [blk '/f_BUVW'], 'Position', [200 30 260 60], ...
            'Gain', [c '*2/3']);
        add_block('simulink/User-Defined Functions/Fcn', [blk '/f_Bhat'], 'Position', [200 90 300 120], ...
            'Expr', [c '*sqrt((2/3*(u(1)-u(2)/2-u(3)/2))^2 + ((u(2)-u(3))/sqrt(3))^2)']);
        add_block('simulink/User-Defined Functions/Fcn', [blk '/f_phi'], 'Position', [200 150 300 180], ...
            'Expr', 'atan2((u(2)-u(3))/sqrt(3), 2/3*(u(1)-u(2)/2-u(3)/2))');
        for z = {'f_BUVW', 'f_Bhat', 'f_phi'}, add_line(blk, 'i_abc/1', [z{1} '/1']); end
        outports(blk, b, {'f_BUVW/1', 'f_Bhat/1', 'f_phi/1'});

    case 'kennlinienschreiber'
        eingaenge(blk, b);
        add_block('simulink/Signal Routing/Mux', [blk '/Mux'], 'Inputs', '3', 'Position', [200 40 205 160]);
        for k = 1:3, add_line(blk, sprintf('%s/1', b.ein(k).name), sprintf('Mux/%d', k)); end
        add_block('simulink/Sinks/To Workspace', [blk '/Protokoll'], 'Position', [260 85 360 115], ...
            'VariableName', 'kennlinie', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
        add_line(blk, 'Mux/1', 'Protokoll/1');

    case 'leiterschleife'
        eingaenge(blk, b);
        add_block('simulink/Math Operations/Gain', [blk '/w1'], 'Gain', '2*pi*f1', 'Position', [120 120 160 150]);
        add_block('simulink/Continuous/Integrator', [blk '/Int_theta2'], 'Position', [200 120 230 150]);
        add_line(blk, 's/1', 'w1/1');
        add_line(blk, 'w1/1', 'Int_theta2/1');
        system_block(blk, 'Schleife', 'asmbib.Leiterschleife', ...
            {'Bhat', 'l', 'r', 'f1', 'p', 'R2_S', 'L2s_S', 'phi2_fix'}, ...
            {'konv', '3 - 2*konv_phi2', 'modus', 'modus_phi2'});
        add_line(blk, 's/1', 'Schleife/1');
        add_line(blk, 'Int_theta2/1', 'Schleife/2');
        outports(blk, b, [arrayfun(@(k) sprintf('Schleife/%d', k), 1:8, 'UniformOutput', false), {'Int_theta2/1'}]);

    otherwise
        ok = false;
end
end

%% ========================= Hilfsfunktionen =========================
function eingaenge(blk, b)
for k = 1:numel(b.ein)
    add_block('simulink/Sources/In1', [blk '/' b.ein(k).name], ...
        'Position', [40, 40 + 60*(k-1), 70, 54 + 60*(k-1)], 'Port', num2str(k));
end
end

function sys = system_block(blk, name, klasse, gleich, ausdruck)
% MATLAB-System-Block (interpretiert); Eigenschaften = gleichnamige Maskenvariablen bzw. Ausdrücke
sys = [blk '/' name];
add_block('simulink/User-Defined Functions/MATLAB System', sys, 'Position', [300 40 420 340], ...
    'System', klasse, 'SimulateUsing', 'Interpreted execution');
for k = 1:numel(gleich), set_param(sys, gleich{k}, gleich{k}); end
for k = 1:2:numel(ausdruck), set_param(sys, ausdruck{k}, ausdruck{k+1}); end
end

function ausgaenge(blk, b, sys, idx)
[~, name] = fileparts(sys);
outports(blk, b, arrayfun(@(k) sprintf('%s/%d', name, k), idx, 'UniformOutput', false));
end

function outports(blk, b, quelle)
for k = 1:numel(b.aus)
    add_block('simulink/Sinks/Out1', [blk '/' b.aus(k).name], ...
        'Position', [700, 40 + 50*(k-1), 730, 54 + 50*(k-1)], 'Port', num2str(k));
    add_line(blk, quelle{k}, [b.aus(k).name '/1'], 'autorouting', 'on');
end
end
