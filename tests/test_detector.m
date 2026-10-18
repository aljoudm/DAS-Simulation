% TEST_DETECTOR  Effect of detector noise: direct vs coherent detection.
%   Run from the DAS_Sim folder by typing:  test_detector

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P  = params;
F  = fiber_model(P);
ev = define_events(P);
W  = simulate_waterfall(P, F, ev);

Dd = detector(P, W, 'direct');
Dc = detector(P, W, 'coherent');

zk = W.z / 1e3;

% Max-pooling for display (see test_waterfall)
blk  = 10;
nb   = floor(P.Nz / blk);
pool = @(X) squeeze(max(reshape(X(1:nb*blk, :), blk, nb, []), [], 1));
zb   = zk(round(blk/2) : blk : nb*blk);

% Local SNR at every position (mean over time) and phase error
SNRloc = mean(abs(W.E).^2, 2) / Dc.sigma2;          % [Nz x 1], linear
err    = angle(Dc.Y .* conj(W.E));                  % phase error [rad]
sphi   = double(std(err, 0, 2));                    % its std per position

figure('Name','Detector noise','Position',[60 40 1200 850]);

% (a) one trace, clean vs noisy (direct detection)
subplot(2,2,1);
win = W.z >= 5000 & W.z <= 5300;
plot(W.z(win), abs(W.E(win,1)).^2*1e9, 'k', 'LineWidth', 1.2); hold on;
plot(W.z(win), Dd.Y(win,1)*1e9, 'r');
yline(Dd.sigma2*1e9, 'b--', 'noise level');
xlabel('distance [m]'); ylabel('power [nW]'); grid on;
legend('clean', 'measured (direct)', 'Location', 'best');
title('(a) One trace: noise hurts most in the fades');

% (b) differential waterfall WITH noise, log scale
subplot(2,2,2);
Ddiff = abs(diff(Dd.Y, 1, 2));
imagesc(zb, W.t(2:end), 10*log10(pool(Ddiff).' / 1e-9));
axis xy; colorbar; clim([-15 15]);
xlabel('distance [km]'); ylabel('time [s]');
title('(b) |P_{m+1} - P_m| with noise [dB re 1 nW]');
for i = 1:numel(ev)
    text(ev(i).z0/1e3 + 0.15, W.t(end)*0.95, ev(i).type, ...
        'Color','w', 'FontWeight','bold');
end

% (c) phase noise along the fiber (coherent detection)
subplot(2,2,3);
semilogy(zk, sphi, 'Color', [0.6 0.6 0.6]); hold on;
semilogy(zk, 1 ./ sqrt(2*SNRloc), 'r', 'LineWidth', 1);
yline(0.1, 'b--', '0.1 rad');
xlabel('distance [km]'); ylabel('\sigma_\phi [rad]'); grid on;
ylim([1e-3 3]);
legend('measured', 'theory 1/\surd(2 SNR)', 'Location', 'southeast');
title('(c) Phase noise vs distance: spikes = fading points');

% (d) phase noise vs local SNR: validation of the noise model
subplot(2,2,4);
SNRdB = 10*log10(SNRloc);
plot(SNRdB, sphi, '.', 'Color', [0.3 0.5 0.9], 'MarkerSize', 4); hold on;
xx = linspace(-20, 45, 200);
plot(xx, 1 ./ sqrt(2*10.^(xx/10)), 'r', 'LineWidth', 2);
yline(pi/sqrt(3), 'k:', 'random phase (\pi/\surd3)');
xline(10, 'k--', '10 dB');
set(gca, 'YScale', 'log');
xlim([-20 45]); ylim([1e-3 3]); grid on;
xlabel('local SNR [dB]'); ylabel('\sigma_\phi [rad]');
legend('each position', 'theory', 'Location', 'southwest');
title('(d) Phase noise vs SNR: theory holds above ~10 dB');

% Numerical summary
fprintf('\n------ detector checks ------\n');
fprintf('noise power                     : %.3f nW\n', Dc.sigma2*1e9);
fprintf('median local SNR                : %.1f dB\n', median(SNRdB));
fprintf('positions with SNR < 10 dB      : %.1f %%  (fading points)\n', ...
    100*mean(SNRdB < 10));
fprintf('median phase noise              : %.4f rad\n', median(sphi));
fprintf('positions with phase noise > 0.1: %.1f %%\n', 100*mean(sphi > 0.1));
fprintf('-----------------------------\n');