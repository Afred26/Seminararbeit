function parametersatz(blk)
%PARAMETERSATZ Maskenrückruf für die Auswahl "Parametersatz: Standard | Benutzerdefiniert".
%   Bei "Standard" werden alle Felder, die in parameter/asm_standard.m vorkommen,
%   auf die Standardwerte gesetzt und gesperrt. Bei "Benutzerdefiniert" sind sie editierbar.
%   Aufruf aus dem Callback des Maskenparameters "parametersatz": asmbib.parametersatz(gcb)

mo  = Simulink.Mask.get(blk);
S   = asm_standard();
std = strcmp(get_param(blk, 'parametersatz'), 'Standard');

for p = mo.Parameters
    if ~strcmp(p.Type, 'edit') || ~isfield(S, p.Name)
        continue;
    end
    if std
        p.Value   = num2str(S.(p.Name), '%.6g');
        p.Enabled = 'off';
    else
        p.Enabled = 'on';
    end
end
end
