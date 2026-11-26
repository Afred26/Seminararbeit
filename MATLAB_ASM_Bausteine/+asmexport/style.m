function S = style()
%STYLE Uniform slide style for all diagrams and model figures.
%   S = asmexport.style() returns format, font and fixed colours.
%
%   Colours as on the slides (Densborn): L1/L2/L3 blue/orange/grey like the voltage curves of
%   the three-phase supply ([D-ASM] slide 13), flux density red, current blue ([D-ASM] slide 16),
%   field vector green. Bar 1/bar 2 of the conductor loop green/violet.
%   Lines whose DisplayName or Tag contains "L1", "L2", "L3", "Stab 1" or "Stab 2" are
%   coloured automatically by asmexport.slide_figure.

% format 16:9 (PowerPoint standard slide 13.333 x 7.5 inch)
S.width_in      = 13.333;
S.height_in     = 7.5;
S.dpi           = 300;

% font
S.font_name     = 'Arial';
S.font_size     = 14;          % minimum size in pt
S.line_width    = 1.5;         % minimum line width in pt

% fixed colours [r g b]
S.colour.L1     = [0.27 0.45 0.77];
S.colour.L2     = [0.93 0.49 0.19];
S.colour.L3     = [0.55 0.55 0.55];
S.colour.bar1   = [0.00 0.50 0.27];
S.colour.bar2   = [0.55 0.20 0.65];
S.colour.B      = [0.85 0.10 0.10];   % flux density
S.colour.i      = [0.15 0.25 0.80];   % current
S.colour.field  = [0.10 0.65 0.30];   % field vector
S.colour.force  = [0.15 0.25 0.80];   % force arrow

% mapping keyword (in German display names) -> colour for slide_figure
S.mapping = {
    '(^|[^\w])L1($|[^\w])',     'L1'
    '(^|[^\w])L2($|[^\w])',     'L2'
    '(^|[^\w])L3($|[^\w])',     'L3'
    '(^|[^\w])Stab ?1($|[^\w])', 'bar1'
    '(^|[^\w])Stab ?2($|[^\w])', 'bar2'
    };
end
