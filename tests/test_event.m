% TEST_EVENT  Check event injection: where does the trace change, and how?
%   Run from the DAS_Sim folder by typing:  test_event

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P  = params;
F  = fiber_model(P);
ev = define_events(P);
Ne = numel(ev);

%% Figure 1: the vibration signals we inject
figure('Name','Injected events','Position',[80 80 1100 650]);
for i = 1:Ne
    subplot(Ne, 1, i);
    plot(P.t_slow, ev(i).dL*1e9, 'LineWidth', 1);
    ylabel('dL [nm]'); grid on;
    title(sprintf('%s  @ %.0f m', ev(i).name, ev(i).z0));
end
xlabel('time [s]');

%% Snapshot: every event frozen at its own peak elongation
ev_snap = ev;
for i = 1:Ne
    ev_snap(i).phi_t = max(abs(ev(i).phi_t)) * ones(size(ev(i).phi_t));
end
[h1, phi1] = apply_event(F, ev_snap, 1);

T0 = simulate_trace(P, F);          % fiber at rest
T1 = simulate_trace(P, F, h1);      % fiber with vibrations

dP     = abs(T1.Pw - T0.Pw);                   % intensity change
dphi   = angle(T1.E .* conj(T0.E));            % phase change (coherent view)
phi_th = phi1(1:P.os:end);  phi_th = phi_th(1:P.Nz);   % theory on ADC grid

%% Figure 2: what changes in the trace
figure('Name','Effect of events on the trace','Position',[120 60 1100 800]);

subplot(3,1,1);
plot(P.z/1e3, dP*1e9, 'b'); hold on;
for i = 1:Ne, xline(ev(i).z0/1e3, 'r--', ev(i).type); end
xlabel('distance [km]'); ylabel('|\DeltaP| [nW]'); grid on;
title('Intensity change: ONLY at the event locations (zero elsewhere)');

subplot(3,1,2);
iw = 2;                                        % zoom on the walking event
win = abs(P.z - ev(iw).z0) <= 100;
plot(P.z(win), T0.Pw(win)*1e9, 'k', 'LineWidth', 1.2); hold on;
plot(P.z(win), T1.Pw(win)*1e9, 'r--', 'LineWidth', 1.2);
xline(ev(iw).z0, 'b:');
xlabel('distance [m]'); ylabel('power [nW]'); grid on;
legend('at rest', 'with vibration', 'Location', 'best');
title(sprintf('Zoom on %s: speckle changes only within ~ one pulse length', ev(iw).name));

subplot(3,1,3);
plot(P.z/1e3, dphi, 'Color', [0.5 0.5 0.5]); hold on;
plot(P.z/1e3, phi_th, 'r', 'LineWidth', 2);
for i = 1:Ne, xline(ev(i).z0/1e3, 'b:'); end
xlabel('distance [km]'); ylabel('\Delta\phi [rad]'); grid on;
legend('measured phase change', 'theory (cumulative)', 'Location', 'northwest');
title('Phase change: ACCUMULATES after each event (staircase)');

%% Numerical checks
far = P.z > 500 & P.z < 1900;                  % before the first event
fprintf('------ event checks ------\n');
fprintf('max |dP| before first event : %.2e W  (expect 0)\n', max(dP(far)));
fprintf('phase at fiber end          : %.3f rad (theory %.3f)\n', ...
    median(dphi(end-200:end)), phi_th(end));
fprintf('--------------------------\n');