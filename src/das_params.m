function p = das_params(ov)
% DAS_PARAMS  Single source of truth for every device / fibre / signal
%             parameter of the simulation (FEBUS A1-NEO interrogator).
%
%   p = das_params()     returns the parameter struct p.
%   p = das_params(ov)   overrides INPUT symbols first (struct ov, e.g.
%                        struct('L_fiber_sim', 5e3, 'f_rep', 4e3); DERIVED
%                        values are then recomputed. Unknown or derived
%                        names raise an error.
%   das_params           (no output) prints a table: name, value, unit, source.
%
%   Source of the datasheet values: FEBUS Optics A1-NEO datasheet,
%   rev. 20260618. Other files get these values through params.m.
%   Do not hard-code any of these numbers anywhere else.

if nargin < 1, ov = struct(); end

%% --- Taken directly from FEBUS A1-NEO datasheet ---
p.lambda        = 1550e-9;   % operating wavelength [m]
p.alpha_dB_km   = 0.2;       % fibre attenuation assumed by datasheet [dB/km]
p.L_fiber_sim   = 20e3;      % fibre length per channel [m] (20 km range option)
p.dz_res        = 2;         % spatial resolution [m] (datasheet: 1-50 m, typ. 2 m)
p.dz_samp       = 2;         % spatial sampling interval [m] (datasheet: typ. every 2 m)
p.P_DAS         = 170;       % interrogator power consumption [W]

%% --- Assumed (needs citation in report) ---
p.n_g           = 1.468;     % group index of standard SMF at 1550 nm
p.c             = 299792458; % speed of light [m/s]

%% --- Old-device / model parameters FEBUS does not specify ---
p.xi            = 0.78;      % photoelastic correction factor  % NOT FROM FEBUS DATASHEET — old/assumed value
p.scat_per_m    = 5;         % Rayleigh scatterers per metre   % NOT FROM FEBUS DATASHEET — old/assumed value
p.alpha_s_dB_km = 0.17;      % Rayleigh part of loss [dB/km]   % NOT FROM FEBUS DATASHEET — old/assumed value
p.S_capture     = 1e-3;      % backscatter capture fraction    % NOT FROM FEBUS DATASHEET — old/assumed value
p.P0            = 100e-3;    % peak pulse power [W]            % NOT FROM FEBUS DATASHEET — old/assumed value
p.pulse_shape   = 'rect';    % 'rect' or 'gauss'               % NOT FROM FEBUS DATASHEET — old/assumed value
p.Npulses       = 2000;      % pulses (traces) simulated       % NOT FROM FEBUS DATASHEET — old/assumed value
p.os            = 4;         % physical-grid oversampling      % NOT FROM FEBUS DATASHEET — old/assumed value
p.SNR_dB        = 30;        % detector SNR at fibre start [dB]% NOT FROM FEBUS DATASHEET — old/assumed value
p.tau_ref       = 100e-9;    % pulse width that defines SNR_dB [s] % NOT FROM FEBUS DATASHEET — old/assumed value
p.seed          = 42;        % random seed                     % NOT FROM FEBUS DATASHEET — old/assumed value
p.gauge         = 20;        % gauge length [m]                % NOT FROM FEBUS DATASHEET — old/assumed value

%% --- Overrides of the inputs above (used by studies / GUI) ---
fn = fieldnames(ov);
for i = 1:numel(fn)
    if ~isfield(p, fn{i}) && ~strcmp(fn{i}, 'f_rep')
        error('das_params:unknown', 'Unknown or derived parameter "%s".', fn{i});
    end
    p.(fn{i}) = ov.(fn{i});
end
f_rep_override = isfield(ov, 'f_rep');

%% --- DERIVED (compute, never hard-code) ---
p.tau_pulse     = 2*p.n_g*p.dz_res/p.c;          % pulse width, approx. 19.6 ns [s]
p.f_s           = p.c/(2*p.n_g*p.dz_samp);       % sampling rate, approx. 51 MHz [Hz]
p.T_rt          = 2*p.n_g*p.L_fiber_sim/p.c;     % round-trip time [s]
p.f_rep_max     = 1/p.T_rt;                      % approx. 5.1 kHz [Hz]
if f_rep_override
    p.f_rep     = ov.f_rep;
else
    p.f_rep     = 5e3;                           % chosen PRR, must be < f_rep_max [Hz]
end
p.f_vib_max     = p.f_rep/2;                     % Nyquist limit for vibration [Hz]

assert(p.f_rep < p.f_rep_max, 'das_params:f_rep', ...
    ['f_rep = %.0f Hz must be < f_rep_max = %.0f Hz for L_fiber_sim = %.1f km ' ...
     '(pulses would overlap). Lower f_rep or shorten the fibre.'], ...
    p.f_rep, p.f_rep_max, p.L_fiber_sim/1e3);

if nargout == 0
    print_params_table(p);
    clear p
end
end
