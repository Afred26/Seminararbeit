function P = asm_params(scenario)
%ASM_PARAMS Complete, explicit parameter set for run_asm and the GUI ASMApp.
%   P = asm_params()            scenario 'lab'
%   P = asm_params(scenario)    'lab' | 'kloss' | 'loop' | 'slides'
%
%   Basis is parameter/asm_standard.m (motor, Kloss data and conductor loop, all values are
%   example values). Added are grid, load, simulation and evaluation settings with the values
%   of the example models in examples/. The returned struct contains every quantity the
%   simulation uses; run_asm passes them to the model via Simulink.SimulationInput, so a run
%   depends only on this struct (not on the base workspace or on mask defaults).
%
%   Scenarios
%     'lab'     dynamic space-vector model ASM Standard at the grid (ex_startup_load_step)
%     'kloss'   part B: quasi-static Kloss model, run-up and load step (ex_kloss_startup)
%     'loop'    part A: conductor loop of two rotor bars at fixed slip (ex_conductor_loop)
%     'slides'  slides 16-30: ideal rotating field, rotor at rest (ex_slides16_30_rotor_bars)
%
%   Additional fields (units as in the conventions; code identifiers in English)
%     scenario       see above
%     param_set      'standard' | 'custom'   motor values from asm_standard.m or as given
%     connection     'star' | 'delta'        stator winding (terminal box)
%     U_L   [V]      line voltage of the grid (RMS)
%     f1    [Hz]     grid frequency (slides/loop: frequency of the ideal field)
%     phase_seq      'L1-L2-L3' (positive sequence) | 'L1-L3-L2' (negative sequence)
%     t_on  [s]      switch-on time
%     load_type      'constant' | 'fan'       base load
%     M_L   [N*m]    base load (constant: M_L0; fan: torque at the reference speed n_B)
%     dM_L  [N*m]    height of the load step (0: no load step)
%     t_step [s]     time of the load step
%     J_L   [kg*m^2] additional inertia of the load
%     t_end [s]      simulation time ([] for 'loop': loop_periods rotor periods)
%     Bhat  [T]      amplitude of the air-gap flux density (slides, loop)
%     phi2_mode      'fixed' | 'impedance'    displacement angle phi2 (slides, loop)
%     phi2_fix [deg] fixed displacement angle phi2
%     s_loop  [-]    slip of the conductor loop (loop)
%     conv_phi2      +1 | -1                  sign convention of the loop (loop)
%     loop_periods   number of rotor periods T2 = 1/(s*f1) for the loop (loop)
%   Evaluation (asmtools.speed_metrics)
%     n_target_rel   run-up target as fraction of the rated speed n_N (0.9: t at 0.9*n_N)
%     band_rel       tolerance band for settling as fraction of ns (1e-3: +-1.5 rpm)
%     window [s]     averaging window for steady-state values (before the step, at the end)
%     step_margin [s] distance of the pre-step window from t_step (the load step is smoothed with
%                    0.5 ms and acts with 50 % already at t_step; 5 ms = 10 time constants)

arguments
    scenario (1,:) char {mustBeMember(scenario, {'lab', 'kloss', 'loop', 'slides'})} = 'lab'
end

P = asm_standard();
P = rmfield(P, 'info');
P.scenario     = scenario;
P.param_set    = 'standard';
P.connection   = 'star';
P.U_L          = P.U_N;
P.f1           = P.f_N;
P.phase_seq    = 'L1-L2-L3';
P.t_on         = 0;
P.load_type    = 'fan';
P.M_L          = P.M_N;          % fan: M_L = M_N at n_B = n_N (as in the example model)
P.dM_L         = 0.3*P.M_N;      % load step 0.3*M_N at t = 1 s (as in the example model)
P.t_step       = 1;
P.J_L          = 0.01;
P.Bhat         = P.Bhat_N;
P.phi2_fix     = 90;
P.s_loop       = P.sK;
P.conv_phi2    = 1;
P.loop_periods = 2;
P.n_target_rel = 0.9;
P.band_rel     = 1e-3;
P.window       = 0.05;
P.step_margin  = 5e-3;
switch scenario
    case {'lab', 'kloss'}
        P.t_end = 2;
        P.phi2_mode = 'fixed';
    case 'loop'
        P.t_end = [];             % automatic: loop_periods rotor periods
        P.phi2_mode = 'impedance';
    case 'slides'
        P.t_end = 0.04;           % two field revolutions at 50 Hz, rotor at rest
        P.phi2_mode = 'fixed';
end
end
