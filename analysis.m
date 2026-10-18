% ANALYSIS  Parameter studies: how does each design choice affect the DAS?
%
%   Run from the DAS_Sim folder by typing:  analysis
%
%   Four studies (choose which to run with RUN below):
%     1) gauge length   -> captured event amplitude vs noise / localization
%     2) pulse width    -> spatial resolution vs SNR
%     3) detector SNR   -> when does detection fail?
%     4) fiber length   -> performance at the far end of the fiber
%
%   Saves to folder "results":
%     07_study_gauge.png, 08_study_pulse.png, 09_study_snr.png,
%     10_study_length.png, analysis_summary.txt, analysis.mat

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions

RUN = [1 1 1 1];            % [gauge  pulse  SNR  length]  1 = run, 0 = skip

outdir = 'results';
if ~exist(outdir, 'dir'), mkdir(outdir); end
nm   = 1e9;
fid  = fopen(fullfile(outdir, 'analysis_summary.txt'), 'w');
tAll = tic;
S1 = []; S2 = []; S3 = []; S4 = [];

%% ======================= STUDY 1: gauge length =======================
% Simulate once, then re-process the SAME data with different gauges.
if RUN(1)
    fprintf('\n######## STUDY 1: gauge length ########\n');
    P  = params;
    F  = fiber_model(P);
    ev = define_events(P);
    W  = simulate_waterfall(P, F, ev);
    Dc = detector(P, W, 'coherent');
    clear W

    x  = [5 10 20 30 40 60];                    % gauge lengths [m]
    S1 = init_S(numel(x), numel(ev));
    for k = 1:numel(x)
        Pk = params(struct('gauge', x(k)));
        R  = process_das(Pk, Dc);
        S1 = store(S1, k, event_metrics(ev, R), NaN, NaN);
        clear R
    end
    clear Dc
    names = {ev.type};

    fig = figure('Name','Study 1: gauge length','Position',[50 50 1100 430]);
    subplot(1,2,1);
    plot(x, S1.amp, '-o', 'LineWidth', 1.5); hold on; yline(1, 'k--');
    grid on; xlabel('gauge length [m]'); ylabel('amplitude ratio (recovered / injected)');
    legend(names, 'Location', 'southeast');
    title('Captured fraction of each event');
    subplot(1,2,2);
    yyaxis left;  plot(x, S1.bg*nm, '-o', 'LineWidth', 1.5);
    ylabel('background activity [nm rms]');
    yyaxis right; plot(x, mean(abs(S1.perr), 2), '-s', 'LineWidth', 1.5);
    ylabel('mean |position error| [m]');
    grid on; xlabel('gauge length [m]');
    title('Noise and localization vs gauge length');
    save_fig(fig, outdir, '07_study_gauge');
    write_table(fid, 'STUDY 1: gauge length [m]', x, S1, names);
end

%% ======================= STUDY 2: pulse width =======================
% Full re-run for every pulse width. Gauge = max(20 m, 2 x resolution).
if RUN(2)
    fprintf('\n######## STUDY 2: pulse width ########\n');
    x  = [25 50 100 200 400];                   % pulse widths [ns]
    S2 = init_S(numel(x), 4);
    S2.res = zeros(numel(x),1); S2.gauge = zeros(numel(x),1);
    for k = 1:numel(x)
        ov       = struct('tau', x(k)*1e-9);
        P0       = params(ov);
        ov.gauge = max(20, 2*P0.dz_res);
        P        = params(ov);
        F  = fiber_model(P);
        ev = define_events(P);
        W  = simulate_waterfall(P, F, ev);
        Dc = detector(P, W, 'coherent');
        [fad, snr] = fading_metrics(W, Dc, true(P.Nz,1));
        clear W
        R  = process_das(P, Dc);  clear Dc
        S2 = store(S2, k, event_metrics(ev, R), fad, snr);
        S2.res(k) = P.dz_res;  S2.gauge(k) = P.gauge;
        clear R
    end
    names = {ev.type};

    fig = figure('Name','Study 2: pulse width','Position',[50 50 1100 430]);
    subplot(1,2,1);
    yyaxis left;  plot(x, S2.res, '-o', 'LineWidth', 1.5); ylabel('spatial resolution [m]');
    yyaxis right; plot(x, S2.snr, '-s', 'LineWidth', 1.5); ylabel('median local SNR [dB]');
    set(gca, 'XScale', 'log'); xticks(x); grid on; xlabel('pulse width [ns]');
    title('Resolution vs SNR trade-off');
    subplot(1,2,2);
    yyaxis left;  plot(x, S2.fad, '-o', 'LineWidth', 1.5); ylabel('positions with SNR < 10 dB [%]');
    yyaxis right; hc = plot(x, S2.corr, '-s', 'LineWidth', 1.4, 'MarkerSize', 5);
    ylabel('correlation'); ylim([0 1.05]);
    cols = lines(numel(hc) + 1);            % row 1 = fading curve (left axis)
    for ic = 1:numel(hc)                    % yyaxis paints every line the axis colour,
        hc(ic).Color = cols(ic + 1, :);     % so give each event its own colour
        hc(ic).MarkerFaceColor = cols(ic + 1, :);
    end
    set(gca, 'XScale', 'log'); xticks(x); grid on; xlabel('pulse width [ns]');
    legend([{'fading %'}, names], 'Location', 'southeast');
    title('Fading and recovery quality vs pulse width');
    save_fig(fig, outdir, '08_study_pulse');
    write_table(fid, 'STUDY 2: pulse width [ns]', x, S2, names);
end

%% ======================= STUDY 3: detector SNR =======================
% Simulate once, then detect + process with different noise levels.
if RUN(3)
    fprintf('\n######## STUDY 3: detector SNR ########\n');
    P  = params;
    F  = fiber_model(P);
    ev = define_events(P);
    W  = simulate_waterfall(P, F, ev);

    x  = [5 10 15 20 25 30 40];                 % SNR at fiber start [dB]
    S3 = init_S(numel(x), numel(ev));
    for k = 1:numel(x)
        Pk = params(struct('SNR_dB', x(k)));
        Dc = detector(Pk, W, 'coherent');
        [fad, snr] = fading_metrics(W, Dc, true(Pk.Nz,1));
        R  = process_das(Pk, Dc);  clear Dc
        S3 = store(S3, k, event_metrics(ev, R), fad, snr);
        clear R
    end
    clear W
    names = {ev.type};

    fig = figure('Name','Study 3: detector SNR','Position',[50 50 1100 430]);
    subplot(1,2,1);
    plot(x, S3.corr, '-o', 'LineWidth', 1.5); grid on; ylim([0 1.05]);
    xlabel('detector SNR at fiber start [dB]'); ylabel('correlation (recovered vs injected)');
    legend(names, 'Location', 'southeast');
    title('Recovery quality vs detector SNR');
    subplot(1,2,2);
    yyaxis left;  semilogy(x, S3.bg*nm, '-o', 'LineWidth', 1.5); ylabel('background activity [nm rms]');
    yyaxis right; plot(x, S3.fad, '-s', 'LineWidth', 1.5); ylabel('positions with SNR < 10 dB [%]');
    grid on; xlabel('detector SNR at fiber start [dB]');
    title('Noise floor and fading vs detector SNR');
    save_fig(fig, outdir, '09_study_snr');
    write_table(fid, 'STUDY 3: detector SNR [dB]', x, S3, names);
end

%% ======================= STUDY 4: fiber length =======================
% Events placed at fractions of L; WALK (weakest) at 0.9 L = worst case.
% Metrics of fading and background are computed on the last 15 % of fiber.
if RUN(4)
    fprintf('\n######## STUDY 4: fiber length ########\n');
    x  = [5 10 20 30];                          % fiber length [km]
    S4 = init_S(numel(x), 4);
    S4.prf_max = zeros(numel(x),1);
    for k = 1:numel(x)
        L  = x(k)*1e3;
        ov = struct('L', L, 'Npulses', 1000, 'ev_z', L*[0.2 0.9 0.5 0.7]);
        P  = params(ov);
        F  = fiber_model(P);
        ev = define_events(P);
        W  = simulate_waterfall(P, F, ev);
        Dc = detector(P, W, 'coherent');
        [fad, snr] = fading_metrics(W, Dc, P.z(:) > 0.85*L);
        clear W
        R  = process_das(P, Dc);  clear Dc
        m  = event_metrics(ev, R);
        m.bg = median(R.act(R.z > 0.85*L));     % background at the far end
        S4 = store(S4, k, m, fad, snr);
        S4.prf_max(k) = P.PRF_max;
        clear R
    end
    names = {ev.type};

    fig = figure('Name','Study 4: fiber length','Position',[50 50 1100 430]);
    subplot(1,2,1);
    yyaxis left;  plot(x, S4.snr, '-o', 'LineWidth', 1.5); ylabel('median SNR, last 15 % [dB]');
    yyaxis right; plot(x, S4.prf_max/1e3, '-s', 'LineWidth', 1.5); ylabel('max PRF [kHz]');
    grid on; xlabel('fiber length [km]');
    title('Far-end SNR and maximum PRF vs length');
    subplot(1,2,2);
    plot(x, S4.corr, '-o', 'LineWidth', 1.5); grid on; ylim([0 1.05]);
    xlabel('fiber length [km]'); ylabel('correlation (recovered vs injected)');
    legend(strcat(names, {' @0.2L',' @0.9L',' @0.5L',' @0.7L'}), 'Location', 'southwest');
    title('Recovery quality vs fiber length');
    save_fig(fig, outdir, '10_study_length');
    write_table(fid, 'STUDY 4: fiber length [km] (bg/fading/SNR at far end)', x, S4, names);
end

%% ======================= save =======================
fclose(fid);
save(fullfile(outdir, 'analysis.mat'), 'S1', 'S2', 'S3', 'S4');
fprintf('\nAnalysis done in %.0f s. Results in folder "%s"\n', toc(tAll), outdir);

%% ======================= local functions =======================
function m = event_metrics(ev, R)
% Correlation, amplitude ratio and position error for every event.
    nm = 1e9;
    for i = 1:numel(ev)
        cand   = find(abs(R.z - ev(i).z0) < 60);
        [~, k] = max(R.act(cand));
        iz     = cand(k);
        est    = double(R.dL(iz, :)) * nm;
        tru    = (ev(i).dL - ev(i).dL(1)) * nm;
        c      = corrcoef(est, tru);
        m.perr(i) = R.z(iz) - ev(i).z0;
        m.amp(i)  = std(est) / std(tru);
        m.corr(i) = c(1,2);
    end
    m.bg = median(R.act);
end

function [fad, msnr] = fading_metrics(W, Dc, mask)
% Percentage of positions with local SNR < 10 dB, and median local SNR.
    s    = 10*log10(double(mean(abs(W.E(mask,:)).^2, 2) / Dc.sigma2));
    fad  = 100 * mean(s < 10);
    msnr = median(s);
end

function S = init_S(n, ne)
    S.corr = nan(n, ne); S.amp = nan(n, ne); S.perr = nan(n, ne);
    S.bg = nan(n, 1); S.fad = nan(n, 1); S.snr = nan(n, 1);
end

function S = store(S, k, m, fad, snr)
    S.corr(k,:) = m.corr; S.amp(k,:) = m.amp; S.perr(k,:) = m.perr;
    S.bg(k) = m.bg; S.fad(k) = fad; S.snr(k) = snr;
end

function write_table(fid, ttl, x, S, names)
% Same table on screen (1) and in the summary file (fid).
    for out = [1 fid]
        fprintf(out, '\n===== %s =====\n', ttl);
        fprintf(out, '%8s %8s %8s', 'value', 'fade%', 'SNR');
        for i = 1:numel(names), fprintf(out, ' %9s', ['corr_' names{i}]); end
        for i = 1:numel(names), fprintf(out, ' %9s', ['amp_'  names{i}]); end
        fprintf(out, ' %9s\n', 'bg[nm]');
        for k = 1:numel(x)
            fprintf(out, '%8.4g %8.2f %8.1f', x(k), S.fad(k), S.snr(k));
            fprintf(out, ' %9.3f', S.corr(k,:));
            fprintf(out, ' %9.2f', S.amp(k,:));
            fprintf(out, ' %9.2f\n', S.bg(k)*1e9);
        end
    end
end

function save_fig(fig, outdir, name)
    file = fullfile(outdir, [name '.png']);
    try
        exportgraphics(fig, file, 'Resolution', 200);
    catch
        print(fig, file, '-dpng', '-r200');
    end
end