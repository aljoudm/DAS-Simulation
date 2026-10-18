% MAIN  Complete DAS (phi-OTDR) simulation: simulate, detect, process, save.
%
%   Run from the DAS_Sim folder by typing:  main
%
%   Creates a folder "results" with:
%     01_backscatter_trace.png    Rayleigh trace vs theory + speckle statistics
%     02_amplitude_waterfall.png  raw and differential power (direct detection)
%     03_phase_waterfall.png      recovered dL waterfall + event localization
%     04_recovered_events.png     recovered vs injected dL for every event
%     05_event_spectra.png        frequency signature of every event
%     06_fading_phase_noise.png   phase noise vs local SNR (fading)
%     summary.txt                 parameters and validation metrics
%     results.mat                 metrics and small result arrays

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions
outdir = 'results';
if ~exist(outdir, 'dir'), mkdir(outdir); end
nm = 1e9;

%% =================== 1) SETUP ===================
P  = params;
params;                                  % print system summary
F  = fiber_model(P);
ev = define_events(P);
Ne = numel(ev);

%% =================== 2) SIMULATE ===================
W  = simulate_waterfall(P, F, ev);

%% =================== 3) DETECT ===================
Dd = detector(P, W, 'direct');
Dc = detector(P, W, 'coherent');

%% =================== 4) PROCESS ===================
R  = process_das(P, Dc);

%% =================== 5) METRICS ===================
% Backscatter statistics (pulse 1, fiber at rest except events)
P_theory = F.P_bs0 * exp(-2 * P.alpha * P.z(:));
Pw1      = abs(double(W.E(:,1))).^2;
keep     = P.Nw+1 : P.Nz;
ratio    = Pw1(keep) ./ P_theory(keep);

% Fading / phase noise
SNRloc = mean(abs(W.E).^2, 2) / Dc.sigma2;
sphi   = double(std(angle(Dc.Y .* conj(W.E)), 0, 2));
SNRdB  = 10*log10(double(SNRloc));

% Event recovery
iz = zeros(Ne,1); est = cell(Ne,1); tru = cell(Ne,1);
M  = struct('name',{},'pos_err',{},'amp_ratio',{},'corr',{});
for i = 1:Ne
    cand   = find(abs(R.z - ev(i).z0) < 60);
    [~, k] = max(R.act(cand));
    iz(i)  = cand(k);
    est{i} = double(R.dL(iz(i), :)) * nm;
    tru{i} = (ev(i).dL - ev(i).dL(1)) * nm;
    c      = corrcoef(est{i}, tru{i});
    M(i).name      = ev(i).name;
    M(i).pos_err   = R.z(iz(i)) - ev(i).z0;
    M(i).amp_ratio = std(est{i}) / std(tru{i});
    M(i).corr      = c(1,2);
end

% Calibration sine
N  = numel(R.t);
f  = (0:N/2-1) * P.PRF / N;
x  = est{1} - mean(est{1});
X  = abs(fft(x)) / N * 2;
[sine_amp, k] = max(X(2:N/2));
sine_freq = f(k+1);

%% =================== 6) FIGURES ===================
zk   = P.z / 1e3;
blk  = 10;
poolmax  = @(X, n) squeeze(max (reshape(X(1:floor(n/blk)*blk, :), blk, floor(n/blk), []), [], 1));
poolmean = @(X, n) squeeze(mean(reshape(X(1:floor(n/blk)*blk, :), blk, floor(n/blk), []), 1));
zb   = zk(round(blk/2) : blk : floor(P.Nz/blk)*blk);
zbR  = R.z(round(blk/2) : blk : floor(numel(R.z)/blk)*blk) / 1e3;

% ---- Figure 1: backscatter trace ----
fig = figure('Name','Backscatter trace','Position',[50 50 1100 420]);
subplot(1,2,1);
plot(zk, 10*log10(Pw1/1e-3), 'Color', [0.6 0.6 0.6]); hold on;
plot(zk, 10*log10(P_theory/1e-3), 'r', 'LineWidth', 2);
xlabel('distance [km]'); ylabel('power [dBm]'); ylim([-75 -35]); grid on;
legend('simulated trace', 'theory P_{bs0} e^{-2\alphaz}', 'Location', 'southwest');
title('Rayleigh backscatter trace (single pulse)');
subplot(1,2,2);
histogram(ratio, 80, 'Normalization', 'pdf'); hold on;
xx = linspace(0, 6, 200); plot(xx, exp(-xx), 'r', 'LineWidth', 2);
xlim([0 6]); grid on;
xlabel('P / P_{theory}'); ylabel('pdf');
legend('simulated', 'exponential e^{-x}');
title('Speckle statistics');
save_fig(fig, outdir, '01_backscatter_trace');

% ---- Figure 2: amplitude waterfall ----
fig = figure('Name','Amplitude waterfall','Position',[50 50 1100 450]);
subplot(1,2,1);
imagesc(zb, W.t, 10*log10(poolmean(abs(W.E).^2, P.Nz).'/1e-3));
axis xy; colorbar; clim([-60 -40]);
xlabel('distance [km]'); ylabel('time [s]');
title('Raw power [dBm]');
subplot(1,2,2);
Ddiff = abs(diff(Dd.Y, 1, 2));
imagesc(zb, W.t(2:end), 10*log10(poolmax(Ddiff, P.Nz).'/1e-9));
axis xy; colorbar; clim([-15 15]);
xlabel('distance [km]'); ylabel('time [s]');
title('|P_{m+1} - P_m| [dB re 1 nW] (direct detection)');
add_labels(ev, W.t(end));
save_fig(fig, outdir, '02_amplitude_waterfall');
clear Ddiff Dd

% ---- Figure 3: phase waterfall + localization ----
fig = figure('Name','Phase waterfall','Position',[50 50 1100 450]);
subplot(1,2,1);
imagesc(zbR, R.t, poolmax(abs(R.dL), numel(R.z)).' * nm);
axis xy; colorbar; clim([0 60]);
xlabel('distance [km]'); ylabel('time [s]');
title('|dL| [nm] (coherent, phase-based)');
add_labels(ev, R.t(end));
subplot(1,2,2);
plot(R.z/1e3, R.act*nm, 'b'); grid on; hold on;
for i = 1:Ne, xline(ev(i).z0/1e3, 'r--', ev(i).type); end
xlabel('distance [km]'); ylabel('activity [nm rms, > 5 Hz]');
title(sprintf('Event localization (gauge = %.0f m)', P.gauge));
save_fig(fig, outdir, '03_phase_waterfall');

% ---- Figure 4: recovered vs injected ----
fig = figure('Name','Recovered events','Position',[50 50 1100 800]);
for i = 1:Ne
    subplot(Ne, 1, i);
    plot(R.t, tru{i}, 'k', 'LineWidth', 1.5); hold on;
    plot(R.t, est{i}, 'r--', 'LineWidth', 1);
    ylabel('dL [nm]'); grid on;
    title(sprintf('%s @ %.0f m   (corr = %.3f, amp ratio = %.2f)', ...
          ev(i).name, ev(i).z0, M(i).corr, M(i).amp_ratio));
    if i == 1, legend('injected', 'recovered', 'Location', 'eastoutside'); end
end
xlabel('time [s]');
save_fig(fig, outdir, '04_recovered_events');

% ---- Figure 5: spectra ----
fig = figure('Name','Event spectra','Position',[50 50 800 500]);
hold on;
for i = 1:Ne
    xi = est{i} - mean(est{i});
    Xi = abs(fft(xi)) / N * 2;
    plot(f, 20*log10(Xi(1:N/2) + 1e-3), 'LineWidth', 1);
end
xlim([0 200]); ylim([-40 40]); grid on;
xlabel('frequency [Hz]'); ylabel('amplitude [dB re 1 nm]');
legend({ev.type}, 'Location', 'northeast');
title('Frequency signature at each event location');
save_fig(fig, outdir, '05_event_spectra');

% ---- Figure 6: fading ----
fig = figure('Name','Fading','Position',[50 50 1100 450]);
subplot(1,2,1);
semilogy(zk, sphi, 'Color', [0.6 0.6 0.6]); hold on;
semilogy(zk, 1 ./ sqrt(2*double(SNRloc)), 'r', 'LineWidth', 1);
xlabel('distance [km]'); ylabel('\sigma_\phi [rad]'); ylim([1e-3 3]); grid on;
legend('measured', 'theory 1/\surd(2 SNR)', 'Location', 'southeast');
title('Phase noise along the fiber (spikes = fading)');
subplot(1,2,2);
plot(SNRdB, sphi, '.', 'Color', [0.3 0.5 0.9], 'MarkerSize', 4); hold on;
xx = linspace(-20, 45, 200);
plot(xx, 1 ./ sqrt(2*10.^(xx/10)), 'r', 'LineWidth', 2);
xline(10, 'k--', '10 dB');
set(gca, 'YScale', 'log'); xlim([-20 45]); ylim([1e-3 3]); grid on;
xlabel('local SNR [dB]'); ylabel('\sigma_\phi [rad]');
legend('each position', 'theory', 'Location', 'southwest');
title('Phase noise vs local SNR');
save_fig(fig, outdir, '06_fading_phase_noise');

%% =================== 7) SUMMARY ===================
fid = fopen(fullfile(outdir, 'summary.txt'), 'w');
for out = [1 fid]                                   % 1 = screen, fid = file
    fprintf(out, '========== DAS SIMULATION SUMMARY ==========\n');
    fprintf(out, 'Fiber length          : %.1f km\n', P.L/1e3);
    fprintf(out, 'Pulse width           : %.0f ns  -> resolution %.2f m\n', P.tau*1e9, P.dz_res);
    fprintf(out, 'PRF                   : %.0f Hz  -> max vibration %.0f Hz\n', P.PRF, P.f_vib_max);
    fprintf(out, 'Recording             : %.1f s (%d pulses)\n', P.T_rec, P.Npulses);
    fprintf(out, 'Detector SNR at start : %.0f dB\n', P.SNR_dB);
    fprintf(out, 'Gauge length          : %.0f m\n\n', P.gauge);

    fprintf(out, '--- Backscatter model ---\n');
    fprintf(out, 'Backscatter at start  : %.1f dBm\n', F.P_bs0_dBm);
    fprintf(out, 'mean(P/P_theory)      : %.3f  (theory 1)\n', mean(ratio));
    fprintf(out, 'std/mean (speckle)    : %.3f  (theory 1)\n\n', std(ratio)/mean(ratio));

    fprintf(out, '--- Fading ---\n');
    fprintf(out, 'Median local SNR      : %.1f dB\n', median(SNRdB));
    fprintf(out, 'Positions SNR < 10 dB : %.1f %%\n', 100*mean(SNRdB < 10));
    fprintf(out, 'Median phase noise    : %.4f rad\n\n', median(sphi));

    fprintf(out, '--- Event recovery ---\n');
    fprintf(out, '%-28s %9s %10s %8s\n', 'event', 'pos err', 'amp ratio', 'corr');
    for i = 1:Ne
        fprintf(out, '%-28s %7.1f m %10.2f %8.3f\n', M(i).name, ...
                M(i).pos_err, M(i).amp_ratio, M(i).corr);
    end
    fprintf(out, '\nCalibration sine      : %.1f Hz, %.1f nm (injected 100 Hz, 30 nm)\n', ...
            sine_freq, sine_amp);
    fprintf(out, 'Background activity   : %.2f nm rms\n', median(R.act)*nm);
    fprintf(out, '============================================\n');
end
fclose(fid);

act_profile = R.act; z_profile = R.z;
save(fullfile(outdir, 'results.mat'), 'P', 'M', 'sine_freq', 'sine_amp', ...
     'act_profile', 'z_profile', 'est', 'tru');
fprintf('\nAll results saved in folder "%s"\n', outdir);

%% =================== local functions ===================
function save_fig(fig, outdir, name)
    file = fullfile(outdir, [name '.png']);
    try
        exportgraphics(fig, file, 'Resolution', 200);
    catch
        print(fig, file, '-dpng', '-r200');
    end
end

function add_labels(ev, tmax)
    for i = 1:numel(ev)
        text(ev(i).z0/1e3 + 0.15, tmax*0.95, ev(i).type, ...
             'Color', 'w', 'FontWeight', 'bold');
    end
end