% TEST_TRACE  First phi-OTDR trace + physical checks.
%   Run from the DAS_Sim folder by typing:  test_trace

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P = params;
F = fiber_model(P);
T = simulate_trace(P, F);
p = pulse(P);

% Theoretical mean backscatter power vs distance
P_theory = F.P_bs0 * exp(-2 * P.alpha * P.z);

% Skip the first pulse length (pulse still entering the fiber)
Np   = numel(p);
keep = ceil(Np / P.os) + 1 : P.Nz;

figure('Name','First DAS trace','Position',[100 100 1100 750]);

% (a) pulse shape
subplot(2,2,1);
stairs((0:Np-1)*P.dz_fine, p, 'LineWidth', 1.5);
xlabel('distance [m]'); ylabel('field amplitude');
title(sprintf('Pulse: %s, \\tau = %.0f ns -> %.1f m', ...
    P.pulse_shape, P.tau*1e9, P.dz_res));
ylim([0 1.2]); grid on;

% (b) full trace in dBm with theory
subplot(2,2,2);
plot(P.z/1e3, 10*log10(T.Pw/1e-3), 'Color', [0.6 0.6 0.6]); hold on;
plot(P.z/1e3, 10*log10(P_theory/1e-3), 'r', 'LineWidth', 2);
xlabel('distance [km]'); ylabel('power [dBm]');
title('Full trace: speckle around the theoretical decay');
legend('simulated', 'theory: P_{bs0} e^{-2\alphaz}', 'Location', 'southwest');
ylim([-75 -35]); grid on;

% (c) zoom: 300 m window, linear scale
subplot(2,2,3);
win = P.z >= 5000 & P.z <= 5300;
plot(P.z(win), T.Pw(win)*1e9, 'b', 'LineWidth', 1);
xlabel('distance [m]'); ylabel('power [nW]');
title('Zoom 5.0-5.3 km: speckle grains ~ pulse length'); grid on;

% (d) statistics: normalized power should be exponential
subplot(2,2,4);
r = T.Pw(keep) ./ P_theory(keep)';
histogram(r, 80, 'Normalization', 'pdf'); hold on;
xx = linspace(0, 6, 200);
plot(xx, exp(-xx), 'r', 'LineWidth', 2);
xlim([0 6]);
xlabel('P / P_{theory}'); ylabel('pdf');
title('Speckle statistics: should follow e^{-x}');
legend('simulated', 'exponential', 'Location', 'northeast'); grid on;

% Numerical checks
fprintf('\n------ trace checks ------\n');
fprintf('Pulse length              : %d fine cells (%.2f m)\n', Np, Np*P.dz_fine);
fprintf('mean(P / P_theory)        : %.3f   (expect ~1)\n', mean(r));
fprintf('std(P) / mean(P)          : %.3f   (expect ~1, exponential)\n', std(r)/mean(r));
fprintf('Fraction with P > 3*mean  : %.3f   (expect e^-3 = 0.050)\n', mean(r > 3));
fprintf('--------------------------\n');