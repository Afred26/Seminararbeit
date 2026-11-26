function S = category_style(category)
%CATEGORY_STYLE Colour scheme and display names of the library categories.
%   S = asmtools.category_style()            struct with all categories
%   s = asmtools.category_style(category)    entry of one category
%   Fields per category: display (sub-library name shown in the library, German),
%   background, foreground [r g b]
%
%   The colours of the diagrams (L1/L2/L3, bar 1/2) are defined in asmexport.style.

S.sources   = entry('Quellen',     [1.00 0.86 0.66], [0.60 0.30 0.00]);
S.machine   = entry('Maschine',    [0.74 0.86 1.00], [0.00 0.25 0.55]);
S.mechanics = entry('Mechanik',    [0.82 0.92 0.76], [0.15 0.40 0.10]);
S.sensors   = entry('Messgeräte',  [1.00 0.98 0.70], [0.45 0.38 0.00]);
S.didactics = entry('Didaktik',    [0.90 0.82 1.00], [0.35 0.15 0.55]);
S.reference = entry('Referenz',    [0.88 0.88 0.88], [0.25 0.25 0.25]);

if nargin > 0
    S = S.(category);
end
end

function e = entry(display, background, foreground)
e = struct('display', display, 'background', background, 'foreground', foreground);
end
