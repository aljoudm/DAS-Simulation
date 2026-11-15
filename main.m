% MAIN  Complete DAS (phi-OTDR) simulation: simulate, detect, process, save.
%
%   Run from the DAS_Sim folder by typing:  main
%
%   Creates a folder "results_febus" (src/results_dir.m) with:
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
outdir = results_dir();
if ~exist(outdir, 'dir'), mkdir(outdir); end
nm = 1e9;

%% =================== 1) SETUP ===================
P  = params;
params;                                  % print system summary
print_expected_signal(das_params);       % analytic backscatter power and SNR vs distance
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
% Report style (no in-figure titles, panel labels, png 300 dpi + pdf). The data
% shown is exactly the data above: only the presentation differs.
fig_style();
zk   = P.z / 1e3;
blk  = 10;
poolmax  = @(X, n) squeeze(max (reshape(X(1:floor(n/blk)*blk, :), blk, floor(n/blk), []), [], 1));
poolmean = @(X, n) squeeze(mean(reshape(X(1:floor(n/blk)*blk, :), blk, floor(n/blk), []), 1));
zb   = zk(round(blk/2) : blk : floor(P.Nz/blk)*blk);
zbR  = R.z(round(blk/2) : blk : floor(numel(R.z)/blk)*blk) / 1e3;
zwin = 100;                                   % half-width of the zoom panels [m]
lett = {'(a)','(b)','(c)','(d)','(e)','(f)','(g)','(h)','(i)','(j)'};

% ---- Figure 1: backscatter trace ----
fig = figure('Position',[50 50 1000 400]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
plot(zk, 10*log10(Pw1/1e-3), 'Color', [0.6 0.6 0.6]); hold on;
plot(zk, 10*log10(P_theory/1e-3), 'r', 'LineWidth', 2);
xlabel('distance [km]'); ylabel('power [dBm]'); ylim([-90 -25]); xlim([0 zk(end)]);
legend({'simulated trace', 'theory'}, 'Location', 'north', 'NumColumns', 2);   % headroom band: deep fades stay visible
panel_label(ax, '(a)');
ax = nexttile;
histogram(ratio, 80, 'Normalization', 'pdf'); hold on;
xx = linspace(0, 6, 200); plot(xx, exp(-xx), 'r', 'LineWidth', 2);
xlim([0 6]); xlabel('P / P_{theory} [-]'); ylabel('pdf [-]');
legend({'simulated', 'exponential e^{-x}'}, 'Location', 'east');
panel_label(ax, '(b)');
save_fig_hq(fig, outdir, '01_backscatter_trace');

% ---- Figure 2: amplitude waterfall (full span + zoom on each event) ----
fig = figure('Position',[50 50 1100 760]);
tl  = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
top = tiledlayout(tl, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); top.Layout.Tile = 1;
ax = nexttile(top);
imagesc(zb, W.t, 10*log10(poolmean(abs(W.E).^2, P.Nz).'/1e-3));
axis xy; clim([-60 -40]); grid(ax, 'off'); cb = colorbar; cb.Label.String = 'raw power [dBm]';
xlabel('distance [km]'); ylabel('time [s]'); panel_label(ax, '(a)');
ax = nexttile(top);
Ddiff = abs(diff(Dd.Y, 1, 2));
imagesc(zb, W.t(2:end), 10*log10(poolmax(Ddiff, P.Nz).'/1e-9));
axis xy; clim([-15 15]); grid(ax, 'off'); cb = colorbar; cb.Label.String = '|P_{m+1} - P_m| [dB re 1 nW]';
hold on; mark_events(ax, ev, W.t(end));
xlabel('distance [km]'); ylabel('time [s]'); panel_label(ax, '(b)');
Zs = cell(1, Ne); zw = cell(1, Ne);
for i = 1:Ne
    win   = abs(P.z(:) - ev(i).z0) <= zwin;
    zw{i} = P.z(win) - ev(i).z0;
    Zs{i} = 10*log10(Ddiff(win, :).'/1e-9);
end
plot_event_zooms(tl, 2, Zs, zw, W.t(2:end), ev, [-15 15], [], '|P_{m+1} - P_m| [dB re 1 nW]', lett(3:6));
save_fig_hq(fig, outdir, '02_amplitude_waterfall');
clear Ddiff Dd Zs

% ---- Figure 3: phase waterfall + localization + zoom ----
fig = figure('Position',[50 50 1100 760]);
tl  = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
top = tiledlayout(tl, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); top.Layout.Tile = 1;
ax = nexttile(top);
imagesc(zbR, R.t, poolmax(abs(R.dL), numel(R.z)).' * nm);
axis xy; clim([0 60]); grid(ax, 'off'); cb = colorbar; cb.Label.String = 'peak |\DeltaL| [nm]';
hold on; mark_events(ax, ev, R.t(end));
xlabel('distance [km]'); ylabel('time [s]'); panel_label(ax, '(a)');
ax = nexttile(top);
plot(R.z/1e3, R.act*nm, 'b'); hold on;
for i = 1:Ne, xline(ev(i).z0/1e3, 'r--', ev(i).type, 'LabelVerticalAlignment', 'top'); end
xlim([0 R.z(end)/1e3]);
xlabel('distance [km]'); ylabel('activity, > 5 Hz [nm rms]'); panel_label(ax, '(b)');
Zs = cell(1, Ne); zw = cell(1, Ne);
for i = 1:Ne
    win   = abs(R.z(:) - ev(i).z0) <= zwin;
    zw{i} = R.z(win) - ev(i).z0;
    Zs{i} = abs(double(R.dL(win, :))).' * nm;
end
plot_event_zooms(tl, 2, Zs, zw, R.t, ev, [0 60], [], '|\DeltaL| [nm]', lett(3:6));
save_fig_hq(fig, outdir, '03_phase_waterfall');
clear Zs

% ---- Figure 4: recovered vs injected (full record | short window) ----
fig = figure('Position',[50 50 1100 820]);
tiledlayout(Ne, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:Ne
    [~, ipk] = max(abs(tru{i}));  tpk = R.t(ipk);
    switch ev(i).type                       % short window: a few periods / one impact
        case 'sine',    tw = [P.T_rec/2,        P.T_rec/2 + 0.06];
        case 'walk',    tw = [tpk - 0.03,       tpk + 0.27];
        case 'dig',     tw = [tpk - 0.03,       tpk + 0.37];
        otherwise,      tw = [P.T_rec/2 - 0.12, P.T_rec/2 + 0.12];
    end
    for c = 1:2
        ax = nexttile;
        plot(R.t, tru{i}, 'k', 'LineWidth', 1.6); hold on;
        plot(R.t, est{i}, 'r--', 'LineWidth', 1.1);
        if c == 2, xlim(tw); else, xlim([0 R.t(end)]); end
        yl = ylim; ylim([yl(1), yl(2) + 0.22*diff(yl)]);          % headroom for label and legend
        if c == 1
            ylabel({sprintf('%s, %.0f km', ev(i).type, ev(i).z0/1e3), '\DeltaL [nm]'});
            panel_label(ax, sprintf('(%c) corr = %.3f, amp. ratio = %.2f', ...
                        char(96 + 2*i - 1), M(i).corr, M(i).amp_ratio));
        else
            panel_label(ax, sprintf('(%c) zoom', char(96 + 2*i)));
            if i == 1, legend({'injected', 'recovered'}, 'Location', 'north', 'NumColumns', 2); end
        end
        if i == Ne, xlabel('time [s]'); end
    end
end
save_fig_hq(fig, outdir, '04_recovered_events');

% ---- Figure 5: spectra ----
fig = figure('Position',[50 50 800 480]);
hold on;
for i = 1:Ne
    xi = est{i} - mean(est{i});
    Xi = abs(fft(xi)) / N * 2;
    plot(f, 20*log10(Xi(1:N/2) + 1e-3), 'LineWidth', 1);
end
xlim([-5 200]); ylim([-40 40]);          % start below 0 Hz so the low-frequency peak is not clipped
xlabel('frequency [Hz]'); ylabel('amplitude [dB re 1 nm]');
legend({ev.type}, 'Location', 'northeast');
save_fig_hq(fig, outdir, '05_event_spectra');

% ---- Figure 6: fading ----
fig = figure('Position',[50 50 1000 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
semilogy(zk, 1 ./ sqrt(2*double(SNRloc)), 'r', 'LineWidth', 1.4); hold on;
semilogy(zk, sphi, 'Color', [0.1 0.1 0.1], 'LineWidth', 0.5);      % measured drawn on top
xlabel('distance [km]'); ylabel('\sigma_\phi [rad]'); ylim([1e-3 3]); xlim([0 zk(end)]);
legend({'theory 1/\surd(2 SNR)', 'measured'}, 'Location', 'southeast');
panel_label(ax, '(a)');
ax = nexttile;
plot(SNRdB, sphi, '.', 'Color', [0.3 0.5 0.9], 'MarkerSize', 4); hold on;
xx = linspace(-20, 45, 200);
plot(xx, 1 ./ sqrt(2*10.^(xx/10)), 'r', 'LineWidth', 2);
xline(10, 'k--', '10 dB');
set(gca, 'YScale', 'log'); xlim([-20 45]); ylim([1e-3 3]);
xlabel('local SNR [dB]'); ylabel('\sigma_\phi [rad]');
legend({'each position', 'theory'}, 'Location', 'southwest');
panel_label(ax, '(b)');
save_fig_hq(fig, outdir, '06_fading_phase_noise');

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

