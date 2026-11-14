function P = params(ov)
% PARAMS  Legacy-named parameter struct P used by every simulation file.
%
%   All device / fibre / signal VALUES now come from das_params.m (FEBUS
%   A1-NEO). This file only maps those values to the legacy field names
%   (P.L, P.n, P.tau, P.fs, P.PRF, ...) and computes model quantities.
%
%   P = params()     returns a struct P used by every other file.
%   P = params(ov)   same, but first overrides INPUT fields with struct ov,
%                    e.g. params(struct('tau', 50e-9)), so DERIVED values
%                    are recomputed correctly (used by analysis.m).
%                    Legacy names L, n, PRF, alpha_dB, ... are accepted and
%                    forwarded to das_params; tau and fs override the
%                    derived FEBUS values directly.
%   params           (no output) prints a summary of the system.
%
%   Do NOT put numeric values here: edit das_params.m instead.

if nargin < 1, ov = []; end
if isempty(ov), ov = struct(); end

%% ===================== split overrides =====================
% legacy name -> das_params name
map = struct('L','L_fiber_sim', 'n','n_g', 'PRF','f_rep', 'alpha_dB','alpha_dB_km', ...
             'dz_res','dz_res', 'dz_samp','dz_samp', 'lambda','lambda', ...
             'xi','xi', 'scat_per_m','scat_per_m', 'P0','P0', 'pulse_shape','pulse_shape', ...
             'Npulses','Npulses', 'os','os', 'linewidth','linewidth', ...
             'seed','seed', 'gauge','gauge', 'c','c');
ov_p = struct();  ov_P = struct();
fn = fieldnames(ov);
for i = 1:numel(fn)
    if isfield(map, fn{i}),  ov_p.(map.(fn{i})) = ov.(fn{i});
    else,                    ov_P.(fn{i})       = ov.(fn{i});   % tau, fs, ev_z, ...
    end
end

%% ===================== INPUT values (from das_params) =====================
p = das_params(ov_p);
P.c           = p.c;                 % speed of light [m/s]
P.L           = p.L_fiber_sim;       % fiber length [m]
P.n           = p.n_g;               % group index
P.alpha_dB    = p.alpha_dB_km;       % attenuation [dB/km]
P.xi          = p.xi;
P.scat_per_m  = p.scat_per_m;
P.S           = p.S_capture;
P.lambda      = p.lambda;
P.P0          = p.P0;
P.tau         = p.tau_pulse;         % pulse width [s]  -> sets spatial resolution
P.pulse_shape = p.pulse_shape;
P.fs          = p.f_s;               % ADC sampling rate [Hz]
P.PRF         = p.f_rep;             % pulse repetition frequency [Hz]
P.Npulses     = p.Npulses;
P.os          = p.os;
P.P_noise     = p.P_noise;          % receiver noise power [W] (coherent, scales with 1/tau)
P.detection   = p.detection;
P.seed        = p.seed;
P.gauge       = p.gauge;
P.ev_z        = [];                  % optional event positions [m]; [] = use define_events

%% ===================== direct overrides (tau, fs, ev_z, ...) =====================
fn = fieldnames(ov_P);
for i = 1:numel(fn)
    P.(fn{i}) = ov_P.(fn{i});
end
if isfield(ov_P, 'tau') && ~isfield(ov_P, 'P_noise')
    P.P_noise = p.P_noise_ref * (1/P.tau) / p.B_ref;   % noise ∝ bandwidth = 1/tau (Palmieri 2013)
end

%% ===================== DERIVED (do not edit) =====================
P.vg        = P.c / P.n;                    % light speed in fiber [m/s]
P.alpha     = P.alpha_dB / (10*log10(exp(1))) / 1e3;  % [Np/m] (power)
P.alpha_s   = P.alpha;                      % [1/m] only S*alpha_s matters (fixed by R_bs_dB in das_params)
P.dz_res    = P.vg * P.tau / 2;             % spatial resolution [m]
P.dz_adc    = P.vg / (2 * P.fs);            % distance per ADC sample [m]
P.dz_fine   = P.dz_adc / P.os;              % physical simulation grid [m]

P.T_rt      = 2 * P.L / P.vg;               % round-trip time [s]
P.PRF_max   = 1 / P.T_rt;                   % max PRF without overlap [Hz]
P.f_vib_max = P.PRF / 2;                    % max detectable vibration [Hz]

P.beta      = 2*pi*P.n / P.lambda;          % propagation constant [rad/m]
P.k_strain  = 4*pi*P.n*P.xi / P.lambda;     % phase per meter elongation [rad/m]
P.G         = round(P.gauge / P.dz_adc);    % gauge length in ADC samples
P.Nw        = round(P.dz_res / P.dz_adc);   % averaging window = one pulse [samples]

% Grids
P.Nz      = floor(P.L / P.dz_adc);          % ADC samples per trace
P.z       = (0:P.Nz-1) * P.dz_adc;          % distance axis [m]
P.Nfine   = P.Nz * P.os;                    % fine samples per trace
P.z_fine  = (0:P.Nfine-1) * P.dz_fine;      % fine distance axis [m]
P.t_slow  = (0:P.Npulses-1) / P.PRF;        % slow-time axis [s]
P.T_rec   = P.Npulses / P.PRF;              % recording duration [s]

% Memory estimate for the final complex waterfall (double precision)
P.mem_GB  = P.Nz * P.Npulses * 8 / 1e9;          % single-precision complex waterfall

% Backscatter at z = 0 and SNR. SNR_dB is only an override knob (studies, GUI):
% it sets the noise so that SNR at the fibre start equals SNR_dB.
P.P_bs0 = P.P0 * P.S * P.alpha_s * P.dz_res;
if isfield(ov_P, 'SNR_dB'), P.P_noise = P.P_bs0 / 10^(ov_P.SNR_dB/10); end
P.SNR_dB = 10*log10(P.P_bs0 / P.P_noise);          % SNR at fibre start [dB]

%% ===================== sanity checks =====================
if P.PRF > P.PRF_max
    error('params:PRF', ...
        'PRF = %.0f Hz exceeds max %.0f Hz for L = %.1f km (pulses overlap).', ...
        P.PRF, P.PRF_max, P.L/1e3);
end
if P.dz_res < P.dz_adc
    warning('params:undersampled', ...
        'Pulse (%.2f m) shorter than ADC sample (%.2f m): resolution lost.', ...
        P.dz_res, P.dz_adc);
end
if P.mem_GB > 2
    warning('params:memory', ...
        'Waterfall needs ~%.1f GB. Reduce Npulses or L.', P.mem_GB);
end

%% ===================== summary =====================
if nargout == 0
    fprintf('\n========== DAS system summary ==========\n');
    fprintf('Fiber length           : %8.2f km\n',   P.L/1e3);
    fprintf('Light speed in fiber   : %8.3e m/s\n',  P.vg);
    fprintf('Round-trip time        : %8.2f us\n',   P.T_rt*1e6);
    fprintf('Spatial resolution     : %8.2f m\n',    P.dz_res);
    fprintf('ADC sample spacing     : %8.2f m\n',    P.dz_adc);
    fprintf('Samples per trace      : %8d\n',        P.Nz);
    fprintf('PRF (used / max)       : %8.0f / %.0f Hz\n', P.PRF, P.PRF_max);
    fprintf('Max vibration freq     : %8.0f Hz\n',   P.f_vib_max);
    fprintf('Recording duration     : %8.2f s\n',    P.T_rec);
    fprintf('Total loss at fiber end: %8.2f dB (round trip)\n', 2*P.alpha_dB*P.L/1e3);
    fprintf('Waterfall memory       : %8.2f GB\n',   P.mem_GB);
    fprintf('========================================\n\n');
    clear P
end
end