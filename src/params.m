function P = params(ov)
% PARAMS  All parameters of the DAS (phi-OTDR) simulation in one place.
%
%   P = params()     returns a struct P used by every other file.
%   P = params(ov)   same, but first overrides INPUT fields with struct ov,
%                    e.g. params(struct('tau', 50e-9)), so DERIVED values
%                    are recomputed correctly (used by analysis.m)
%   params           (no output) prints a summary of the system.
%
%   Edit the INPUT sections only. The DERIVED section is computed
%   automatically and must not be edited by hand.

%% ===================== INPUT: physical constants =====================
P.c = 299792458;            % speed of light in vacuum [m/s]

%% ===================== INPUT: fiber =====================
P.L          = 10e3;        % fiber length [m]
P.n          = 1.468;       % refractive index of the core (SMF-28 @1550nm)
P.alpha_dB   = 0.2;         % attenuation [dB/km]
P.xi         = 0.78;        % photoelastic correction factor (strain -> phase)
P.scat_per_m = 5;           % Rayleigh scatterers per meter (random positions)
P.alpha_s_dB = 0.17;        % Rayleigh scattering part of the loss [dB/km]
P.S          = 1e-3;        % capture fraction: share of scattered light guided back

%% ===================== INPUT: laser & pulse =====================
P.lambda      = 1550e-9;    % wavelength [m]
P.P0          = 100e-3;     % peak pulse power [W]
P.tau         = 100e-9;     % pulse width [s]  -> sets spatial resolution
P.pulse_shape = 'rect';     % 'rect' or 'gauss' (gauss: tau = FWHM)

%% ===================== INPUT: acquisition =====================
P.fs      = 100e6;          % ADC sampling rate [Hz]  (fast time)
P.PRF     = 1e3;            % pulse repetition frequency [Hz] (slow time)
P.Npulses = 2000;           % number of pulses (traces) to simulate
P.os      = 4;              % oversampling of the physical grid vs ADC grid
P.SNR_dB  = 30;             % detector SNR at fiber start [dB] ...
P.tau_ref = 100e-9;         % ... for a pulse of this width (fixes the noise level)
P.seed    = 42;             % random seed -> same fiber every run

%% ===================== INPUT: processing =====================
P.gauge   = 20;             % gauge length [m]: phase is differenced over this

%% ===================== INPUT: scenario =====================
P.ev_z    = [];             % optional event positions [m]; [] = use define_events

%% ===================== overrides (from params(ov)) =====================
if nargin > 0 && ~isempty(ov)
    fn = fieldnames(ov);
    for i = 1:numel(fn)
        P.(fn{i}) = ov.(fn{i});
    end
end

%% ===================== DERIVED (do not edit) =====================
P.vg        = P.c / P.n;                    % light speed in fiber [m/s]
P.alpha     = P.alpha_dB / (10*log10(exp(1))) / 1e3;  % [Np/m] (power)
P.alpha_s   = P.alpha_s_dB / (10*log10(exp(1))) / 1e3; % [1/m] (power)
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
P.mem_GB  = P.Nz * P.Npulses * 16 / 1e9;

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