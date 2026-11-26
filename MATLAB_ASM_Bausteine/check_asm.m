function S = check_asm(opt)
%CHECK_ASM Complete check for batch runs: release log, unit tests and technical test cases.
%   S = check_asm()                      runs runtests('tests') and verify_asm
%   S = check_asm('Log', file)           also writes the console output to a text file
%   S = check_asm('Build', true)         first rebuilds library and example models
%
%   Command line (exit code ~= 0 if anything fails):
%     matlab -batch "startup_asm; check_asm('Log', 'check_asm.log')"
%
%   Output (German): MATLAB release and versions of Simulink, Simscape and Simscape Electrical,
%   the result of every test class, the report of verify_asm and a summary. The function throws
%   'asm:check' if a unit test fails or is incomplete, or if a verify_asm row is "nicht
%   bestanden", "Fehler" or "nicht verfügbar". Info rows are not counted as passed.
%
%   Returns S with fields release, products, tests (matlab.unittest.TestResult), report (table of
%   verify_asm), passed (logical).

arguments
    opt.Log {mustBeTextScalar} = ''
    opt.Build (1,1) logical = false
end

if ~isempty(opt.Log)
    if exist(opt.Log, 'file'), delete(opt.Log); end
    diary(opt.Log);
    cleanup = onCleanup(@() diary('off'));
end

root = fileparts(mfilename('fullpath'));
fprintf('=== check_asm: %s ===\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
S.release = version('-release');
fprintf('MATLAB %s (R%s), %s\n', version, S.release, computer);
names = {'Simulink', 'Simscape', 'Simscape Electrical'};
installed = ver;                                       % look up by product name
S.products = struct('name', {}, 'version', {});
for k = 1:numel(names)
    v = installed(strcmp({installed.Name}, names{k}));
    if isempty(v)
        fprintf('  %-22s nicht installiert\n', names{k});
    else
        fprintf('  %-22s %s %s\n', v(1).Name, v(1).Version, v(1).Release);
        S.products(end+1) = struct('name', v(1).Name, 'version', v(1).Version);
    end
end

if opt.Build
    build_library();
    build_examples();
end

fprintf('\n--- Unit-Tests: runtests(''tests'') ---\n');
S.tests = runtests(fullfile(root, 'tests'));
n_pass = nnz([S.tests.Passed]);  n_fail = nnz([S.tests.Failed]);  n_inc = nnz([S.tests.Incomplete]);
fprintf('Unit-Tests: %d bestanden, %d fehlgeschlagen, %d unvollständig (von %d)\n', ...
        n_pass, n_fail, n_inc, numel(S.tests));
for k = find([S.tests.Failed] | [S.tests.Incomplete])
    fprintf('  NICHT BESTANDEN: %s\n', S.tests(k).Name);
end

fprintf('\n--- Fachliche Testfälle: verify_asm ---\n');
S.report = verify_asm('Print', true);
bad = ismember(S.report.Status, ["nicht bestanden" "Fehler" "nicht verfügbar"]);

S.passed = n_fail == 0 && n_inc == 0 && ~any(bad);
if S.passed
    fprintf('=== check_asm: ALLES BESTANDEN (%d Unit-Tests, %d Prüfzeilen, %d Info) ===\n', ...
            n_pass, nnz(S.report.Status == "bestanden"), nnz(S.report.Status == "Info"));
else
    msg = sprintf(['check_asm: %d Unit-Test(s) fehlgeschlagen/unvollständig, %d Prüfzeile(n) ' ...
                   'nicht bestanden/abgebrochen/nicht verfügbar'], n_fail + n_inc, nnz(bad));
    fprintf('=== %s ===\n', msg);
    error('asm:check', '%s', msg);
end
end
