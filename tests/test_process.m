% TEST_PROCESS  Full chain: recover dL(t) from the light and compare with truth.
%   Run from the DAS_Sim folder by typing:  test_process

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P  = params;
F  = fiber_model(P);
ev = define_events(P);
W  = simulate_waterfall(P, F, ev);
Dc = detector(P, W, 'coherent');
clear W
R  = process_das(P, Dc);
clear Dc

Ne = numel(ev);
zk = R.z / 1e3;
nm = 1e9;

% Max-pooling for display
blk  = 10;
nb   = floor(numel(R.z) / blk);
pool = @(X) squeeze(max(reshape(X(1:nb*blk, :), blk, nb, []), [], 1));
zb   = zk(round(blk/2) : blk : nb*blk);

% Find each event: position of maximum activity within +-60 m
iz = zeros(Ne,1); est = cell(Ne,1); tru = cell(Ne,1);
for i = 1:Ne
    cand = find(abs(R.z - ev(i).z0) < 60);
    [~, k] = max(R.act(cand));
    iz(i)  = cand(k);
    est{i} = double(R.dL(iz(i), :)) * nm;
    tru{i} = (ev(i).dL - ev(i).dL(1)) * nm;   % phase is relative to pulse 1
end

%% Figure 1: overview
figure('Name','DAS processing','Position',[60 40 1200 850]);

% (a) dL waterfall
subplot(2,2,1);
imagesc(zb, R.t, pool(abs(R.dL)).' * nm);
axis xy; colorbar; clim([0 60]);
xlabel('distance [km]'); ylabel('time [s]');
title('(a) |dL| waterfall [nm] (phase-based)');
for i = 1:Ne
    text(ev(i).z0/1e3 + 0.15, R.t(end)*0.95, ev(i).type, ...
         'Color','w', 'FontWeight','bold');
end

% (b) localization
subplot(2,2,2);
plot(zk, R.act * nm, 'b'); grid on; hold on;
for i = 1:Ne, xline(ev(i).z0/1e3, 'r--', ev(i).type); end
xlabel('distance [km]'); ylabel('activity [nm rms, > 5 Hz]');
title('(b) Activity vs distance: ALL four events visible');

% (c) spectra at each event: the frequency "signature"
subplot(2,2,3);
N = numel(R.t);
f = (0:N/2-1) * P.PRF / N;
hold on;
for i = 1:Ne
    x = est{i} - mean(est{i});
    X = abs(fft(x)) / N * 2;
    plot(f, 20*log10(X(1:N/2) + 1e-3), 'LineWidth', 1);
end
xlim([0 200]); ylim([-40 40]); grid on;
xlabel('frequency [Hz]'); ylabel('amplitude [dB re 1 nm]');
legend({ev.type}, 'Location', 'northeast');
title('(c) Spectrum at each event location');

% (d) calibration event: recovered vs injected, zoom 0-0.1 s
subplot(2,2,4);
k1 = R.t <= 0.1;
plot(R.t(k1), tru{1}(k1), 'k', 'LineWidth', 2); hold on;
plot(R.t(k1), est{1}(k1), 'r--', 'LineWidth', 1.5);
xlabel('time [s]'); ylabel('dL [nm]'); grid on;
legend('injected', 'recovered', 'Location', 'best');
title(sprintf('(d) %s: recovered vs injected', ev(1).name));

%% Figure 2: every event, recovered vs injected
figure('Name','Recovered vs injected','Position',[100 60 1100 800]);
for i = 1:Ne
    subplot(Ne, 1, i);
    plot(R.t, tru{i}, 'k', 'LineWidth', 1.5); hold on;
    plot(R.t, est{i}, 'r--', 'LineWidth', 1);
    ylabel('dL [nm]'); grid on;
    title(sprintf('%s @ %.0f m', ev(i).name, ev(i).z0));
    if i == 1, legend('injected', 'recovered', 'Location', 'eastoutside'); end
end
xlabel('time [s]');

%% Numerical validation
fprintf('\n%-28s %10s %10s %10s\n', 'event', 'pos err', 'amp ratio', 'corr');
for i = 1:Ne
    c = corrcoef(est{i}, tru{i});
    fprintf('%-28s %8.1f m %10.2f %10.3f\n', ev(i).name, ...
            R.z(iz(i)) - ev(i).z0, std(est{i})/std(tru{i}), c(1,2));
end
x = est{1} - mean(est{1});
X = abs(fft(x)) / N * 2;
[a1, k] = max(X(2:N/2));
fprintf('\nCalibration sine: %.1f Hz, %.1f nm  (injected: 100 Hz, 30 nm)\n', ...
        f(k+1), a1);
fprintf('Background activity: %.2f nm rms\n', median(R.act)*nm);