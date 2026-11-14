function p = das_params(ov)
% DAS_PARAMS  Single source of truth for every device / fibre / signal
%             parameter of the simulation (FEBUS A1-NEO interrogator).
%
%   p = das_params()     returns the parameter struct p.
%   p = das_params(ov)   overrides inputs first (struct ov, e.g.
%                        struct('L_fiber_sim', 5e3, 'dz_res', 2); DERIVED
%                        values are then recomputed). Unknown names error.
%   das_params           (no output) prints name | value | unit | source.
%
%   p.src.<name> holds the FINAL source of every value:
%   FEBUS | DATASHEET | DERIVED | ASSUMED: <source> | OVERRIDE (study/GUI).
%
%   When vendor data arrives, edit ONLY the FEBUS overrides block below.
%   Do not hard-code any of these numbers anywhere else.
%
%   Sources: FEBUS A1-NEO datasheet rev. 20260618; Corning SMF-28 Ultra
%   (G.652.D) datasheet PI-1424; Thevenaz 2025; Liu 2016; Zeng 2024;
%   Juarez 2005; Palmieri 2013; Wang 2020.

if nargin < 1 || isempty(ov), ov = struct(); end
src = struct();

%% ----- FEBUS overrides: NaN = not received yet. If set, they replace the
%       assumed/derived value. -----
p.tau_pulse_febus = NaN;  % [s]   [FEBUS]
p.dz_res_febus    = NaN;  % [m]   [FEBUS]
p.f_s_febus       = NaN;  % [Hz]  [FEBUS]
p.f_rep_febus     = NaN;  % [Hz]  [FEBUS]
p.P0_febus        = NaN;  % [W]   [FEBUS]
p.linewidth_febus = NaN;  % [Hz]  [FEBUS]

%% ----- [DATASHEET] FEBUS A1-NEO (rev. 20260618) -----
p.lambda      = 1550e-9;  % operating wavelength [m]            [DATASHEET]
p.L_fiber_sim = 20e3;     % fibre length per channel [m] (20 km option) [DATASHEET]
p.alpha_dB_km = 0.2;      % fibre attenuation [dB/km]           [DATASHEET]
p.dz_samp     = 2;        % channel spacing, "typically every 2 m" [m] [DATASHEET]
p.dz_res      = 10;       % spatial resolution [m], chosen within the datasheet 1-50 m range
                          % (matches Zeng 2024 perimeter DAS, 10.2 m)  [DATASHEET: range 1-50 m; value ASSUMED: Zeng 2024]
p.P_DAS       = 170;      % interrogator power consumption [W]  [DATASHEET]

%% ----- [ASSUMED: source] -----
p.n_g         = 1.4682;   % group index [-]   [ASSUMED: Corning SMF-28 Ultra PI-1424]
p.R_bs_dB     = -82;      % Rayleigh backscatter coeff., 1 ns pulse, 1550 nm [dB]  [ASSUMED: Corning SMF-28 Ultra PI-1424]
                          % ratio for pulse tau: R_bs_dB + 10*log10(tau/1e-9)
p.P0          = 0.1;      % peak pulse power [W]  [ASSUMED: Thevenaz 2025 typical; MI-limited, Liu 2016]
p.linewidth   = 3e3;      % laser linewidth [Hz]  [ASSUMED: Zeng 2024; Juarez 2005]
                          % (carried for documentation; the scatterer model has no laser phase noise)
p.detection   = 'coherent'; % heterodyne, phase + amplitude  [ASSUMED: Zeng 2024]
p.P_noise_ref = 0.2e-9;   % coherent noise floor [W] = 10 dB SNR at ~2 nW, at B_ref  [ASSUMED: Thevenaz 2025]
p.B_ref       = 100e6;    % reference bandwidth for P_noise_ref [Hz] (10 ns pulse)  [ASSUMED: Thevenaz 2025]
p.T_rec_target = 2;       % target recording length [s]  [ASSUMED: project choice]
% Strain-optic factor and numerical modelling choices ([SIM SETTING] = not device/fibre properties):
p.xi          = 0.78;     % strain-optic (photoelastic) factor [-]   [ASSUMED: He & Liu 2021, strain-optic coefficient K_eps ~ 0.78 for standard SMF]
p.scat_per_m  = 5;        % Rayleigh scatterers per metre [1/m]  [SIM SETTING]
p.pulse_shape = 'rect';   % 'rect' or 'gauss'                    [SIM SETTING]
p.os          = 4;        % physical-grid oversampling [-]       [SIM SETTING]
p.seed        = 42;       % random seed                          [SIM SETTING]
p.gauge       = 20;       % gauge length [m]  [CHOSEN: FEBUS supports gauge >= 1 m; 20 m selected by gauge study (fig 07); Wang 2020 — short gauge lowers SNR, long gauge distorts signal]

%% ----- source bookkeeping of the blocks above -----
for nm = {'tau_pulse_febus','dz_res_febus','f_s_febus','f_rep_febus','P0_febus','linewidth_febus'}
    src.(nm{1}) = 'FEBUS (NaN = not received)';
end
for nm = {'lambda','L_fiber_sim','alpha_dB_km','dz_samp','P_DAS'}, src.(nm{1}) = 'DATASHEET'; end
src.dz_res       = 'DATASHEET range 1-50 m; ASSUMED: Zeng 2024';
src.n_g          = 'ASSUMED: Corning PI-1424';
src.R_bs_dB      = 'ASSUMED: Corning PI-1424';
src.P0           = 'ASSUMED: Thevenaz 2025; Liu 2016';
src.linewidth    = 'ASSUMED: Zeng 2024; Juarez 2005';
src.detection    = 'ASSUMED: Zeng 2024';
src.P_noise_ref  = 'ASSUMED: Thevenaz 2025';
src.B_ref        = 'ASSUMED: Thevenaz 2025';
src.T_rec_target = 'ASSUMED: project choice';
src.xi = 'ASSUMED: He & Liu 2021 (K_eps ~ 0.78, std SMF)';
src.gauge = 'CHOSEN: gauge study (fig 07); Wang 2020';
for nm = {'scat_per_m','pulse_shape','os','seed'}
    src.(nm{1}) = 'SIM SETTING';
end

%% ----- Overrides of the inputs above (used by studies / GUI) -----
ovn = fieldnames(ov);
for i = 1:numel(ovn)
    k = ovn{i};
    if any(strcmp(k, {'f_rep', 'Npulses'})), continue; end   % handled below
    if ~isfield(p, k)
        error('das_params:unknown', 'Unknown or derived parameter "%s".', k);
    end
    p.(k) = ov.(k);  src.(k) = 'OVERRIDE (study/GUI)';
end

%% ----- [DERIVED] (FEBUS overrides applied first) -----
p.c   = 299792458;  src.c = 'DERIVED: physical constant';
p.v_g = p.c / p.n_g;  src.v_g = 'DERIVED';

% FEBUS overrides replace assumed values
if ~isnan(p.P0_febus),        p.P0 = p.P0_febus;               src.P0 = 'FEBUS'; end
if ~isnan(p.linewidth_febus), p.linewidth = p.linewidth_febus; src.linewidth = 'FEBUS'; end
if ~isnan(p.dz_res_febus),    p.dz_res = p.dz_res_febus;       src.dz_res = 'FEBUS'; end

if ~isnan(p.tau_pulse_febus)
    p.tau_pulse = p.tau_pulse_febus;  src.tau_pulse = 'FEBUS';
    if isnan(p.dz_res_febus)          % dz_res = c*tau/(2*n_g)
        p.dz_res = p.c * p.tau_pulse / (2*p.n_g);  src.dz_res = 'DERIVED (from FEBUS tau_pulse)';
    end
else
    p.tau_pulse = 2*p.n_g*p.dz_res/p.c;            % approx. 98 ns (Liu 2016)
    src.tau_pulse = 'DERIVED: Liu 2016';
end

if ~isnan(p.f_s_febus)
    p.f_s = p.f_s_febus;  src.f_s = 'FEBUS';
else
    p.f_s = p.c/(2*p.n_g*p.dz_samp);               % approx. 51 MHz (~5 samples/pulse)
    src.f_s = 'DERIVED';
end

p.T_rt      = 2*p.n_g*p.L_fiber_sim/p.c;           % round-trip time [s]
p.f_rep_max = 1/p.T_rt;                            % [Hz]
src.T_rt = 'DERIVED';  src.f_rep_max = 'DERIVED';

if isfield(ov, 'f_rep')
    p.f_rep = ov.f_rep;  src.f_rep = 'OVERRIDE (study/GUI)';
elseif ~isnan(p.f_rep_febus)
    p.f_rep = p.f_rep_febus;  src.f_rep = 'FEBUS';
else
    p.f_rep = 0.9*p.f_rep_max;  src.f_rep = 'DERIVED (0.9 f_rep_max)';
end
assert(p.f_rep < p.f_rep_max, 'das_params:f_rep', ...
    ['f_rep = %.0f Hz must be < f_rep_max = %.0f Hz for L_fiber_sim = %.1f km ' ...
     '(pulses would overlap). Lower f_rep or shorten the fibre.'], ...
    p.f_rep, p.f_rep_max, p.L_fiber_sim/1e3);

p.f_vib_max = p.f_rep/2;                           % Nyquist (Wang 2020)
src.f_vib_max = 'DERIVED: Wang 2020';

if isfield(ov, 'Npulses')
    p.Npulses = ov.Npulses;  src.Npulses = 'OVERRIDE (study/GUI)';
else
    p.Npulses = 2*round(p.T_rec_target * p.f_rep / 2);   % ~2 s recording, even (FFT bins)
    src.Npulses = 'DERIVED (T_rec_target * f_rep, even)';
end
p.T_rec = p.Npulses / p.f_rep;  src.T_rec = 'DERIVED';


% receiver noise (coherent): proportional to bandwidth (Palmieri 2013)
p.B_rx    = 1/p.tau_pulse;                         % receiver bandwidth [Hz]
p.P_noise = p.P_noise_ref * (p.B_rx/p.B_ref);      % [W]
src.B_rx = 'DERIVED';  src.P_noise = 'DERIVED: Palmieri 2013';

% attenuation
p.alpha_lin   = p.alpha_dB_km/(10*log10(exp(1)))/1e3;     % power [1/m]
src.alpha_lin = 'DERIVED';

% Backscatter: R(tau) = 10^((R_bs_dB + 10log10(tau/1ns))/10)  (Corning)
%   P_bs(z) = P0 * R(tau) * 10^(-2*alpha_dB_km*z/1e4)          (z in m)
% The scatterer model uses P_bs0 = P0 * S * alpha_s * (v_g*tau/2). Only the PRODUCT
% S*alpha_s matters (alpha_s cancels), so alpha_s is taken equal to the total
% attenuation alpha_lin and S is set to reproduce the Corning coefficient exactly:
p.S_capture = 10^(p.R_bs_dB/10) / (1e-9 * p.alpha_lin * p.v_g/2);   % [-]
src.S_capture = 'DERIVED: from R_bs_dB (Corning PI-1424)';
p.R_bs_tau  = 10^((p.R_bs_dB + 10*log10(p.tau_pulse/1e-9))/10);       % [-]
p.P_bs0     = p.P0 * p.R_bs_tau;                                      % backscatter at z=0 [W]
p.SNR0_dB   = 10*log10(p.P_bs0/p.P_noise);                            % SNR at z=0 [dB]
src.R_bs_tau = 'DERIVED';  src.P_bs0 = 'DERIVED';  src.SNR0_dB = 'DERIVED';

% memory of the stored waterfall (single complex = 8 B)
p.dz_adc = p.v_g/(2*p.f_s);
p.Nz     = floor(p.L_fiber_sim/p.dz_adc);
p.mem_GB = p.Nz * p.Npulses * 8 / 1e9;
src.dz_adc = 'DERIVED';  src.Nz = 'DERIVED';  src.mem_GB = 'DERIVED';

p.src = src;

if nargout == 0
    print_params_table(p);
    clear p
end
end
