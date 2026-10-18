function ev = define_events(P)
% DEFINE_EVENTS  Scenario: which vibrations happen, where and when.
%
%   ev = define_events(P)   returns a struct array, one element per event.
%
%   Physics: a vibration stretches a short fiber section [z0-w/2, z0+w/2]
%   by dL(t) meters. Light passing that section gets an extra round-trip
%   phase   phi(t) = k_strain * dL(t),   k_strain = 4*pi*n*xi/lambda.
%   Inside the section the extra phase grows linearly (ramp 0 -> 1);
%   every scatterer AFTER the section carries the full phi(t).
%
%   Fields of each event:
%     name, type      label and category
%     z0, w           center [m] and length of the stretched section [m]
%     dL              elongation vs slow time [m]        (1 x Npulses)
%     phi_t           extra phase vs slow time [rad]     (1 x Npulses)
%     ramp            spatial profile on fine grid, 0->1 (Nfine x 1)
%
%   Edit the SCENARIO section to change or add events.

if nargin < 1
    P = params();
end

t = P.t_slow;                 % slow time axis [s]
s_old = rng;                  % keep the fiber's random stream untouched
rng(P.seed + 1);

%% ============================ SCENARIO ============================
k = 0;

% 1) Pure sine: calibration event (known frequency and amplitude)
k = k + 1;
ev(k).name = 'Sine 100 Hz (calibration)';
ev(k).type = 'sine';
ev(k).z0   = 2000;
ev(k).w    = 10;
ev(k).dL   = 30e-9 * sin(2*pi*100*t);

% 2) Walking: footsteps ~1.8 steps/s, each a short damped ring at 30 Hz
k = k + 1;
ev(k).name = 'Walking';
ev(k).type = 'walk';
ev(k).z0   = 4000;
ev(k).w    = 5;
tk = (0.2 : 1/1.8 : P.T_rec);
tk = tk + 0.03*randn(size(tk));                 % natural timing jitter
ev(k).dL = impacts(t, tk, 60e-9, 30, 0.04);

% 3) Digging: strike every ~1.2 s, stronger and rings longer at 120 Hz
k = k + 1;
ev(k).name = 'Digging';
ev(k).type = 'dig';
ev(k).z0   = 6000;
ev(k).w    = 3;
tk = (0.3 : 1.2 : P.T_rec);
tk = tk + 0.05*randn(size(tk));
ev(k).dL = impacts(t, tk, 80e-9, 120, 0.08);

% 4) Vehicle: slow pass (Gaussian envelope) + 25 Hz engine vibration,
%    spread over a longer section of fiber
k = k + 1;
ev(k).name = 'Vehicle';
ev(k).type = 'vehicle';
ev(k).z0   = 8000;
ev(k).w    = 30;
env = exp(-((t - P.T_rec/2) / 0.5).^2);
ev(k).dL = 100e-9 * env .* (0.6 + 0.4*sin(2*pi*25*t));

%% optional: override event positions (used by analysis.m)
if isfield(P, 'ev_z') && ~isempty(P.ev_z)
    for i = 1:numel(ev)
        ev(i).z0 = P.ev_z(i);
    end
end

%% ===================== derived fields (do not edit) =====================
L_sim = P.Nfine * P.dz_fine;
for i = 1:numel(ev)
    if ev(i).z0 - ev(i).w/2 < 0 || ev(i).z0 + ev(i).w/2 > L_sim
        error('define_events:range', 'Event "%s" lies outside the fiber.', ev(i).name);
    end
    ev(i).phi_t = P.k_strain * ev(i).dL;
    z_start     = ev(i).z0 - ev(i).w/2;
    ev(i).ramp  = min(max((P.z_fine(:) - z_start) / ev(i).w, 0), 1);
end

rng(s_old);

%% summary
fprintf('\n%-28s %8s %6s %10s %10s\n', 'event', 'z0 [m]', 'w [m]', 'peak dL', 'peak phi');
for i = 1:numel(ev)
    fprintf('%-28s %8.0f %6.0f %7.1f nm %7.3f rad\n', ev(i).name, ev(i).z0, ...
            ev(i).w, max(abs(ev(i).dL))*1e9, max(abs(ev(i).phi_t)));
end
fprintf('\n');
end

%% ---------------------------------------------------------------------
function dL = impacts(t, tk, A, f_ring, t_decay)
% Sum of damped oscillations starting at times tk (one per impact).
% Each impact has a slightly random amplitude (+-10%).
dL = zeros(size(t));
for j = 1:numel(tk)
    tt = t - tk(j);
    on = tt >= 0;
    Aj = A * (1 + 0.1*randn);
    dL(on) = dL(on) + Aj * exp(-tt(on)/t_decay) .* sin(2*pi*f_ring*tt(on));
end
end