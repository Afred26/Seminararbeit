function param_set_callback(blk)
%PARAM_SET_CALLBACK Mask callback of the popup "Parametersatz: Standard | Benutzerdefiniert".
%   With "Standard" all fields that also exist in parameter/asm_standard.m are set to the
%   standard values and disabled. With "Benutzerdefiniert" they are editable.
%   Called from the callback of the mask parameter "param_set": asmtools.param_set_callback(gcb)

mo  = Simulink.Mask.get(blk);
S   = asm_standard();
std = strcmp(get_param(blk, 'param_set'), 'Standard');

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
