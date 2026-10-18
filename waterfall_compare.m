% WATERFALL_COMPARE  Baseline waterfall (no events) vs event waterfall.
%
%   Run from the DAS_Sim folder by typing:  waterfall_compare
%
%   Both cases use the SAME fiber and the SAME detector noise,
%   so the only difference between them is the events.
%
%   Figure 1 (3 rows x 2 columns), full fiber:
%     row 1  raw power             (what the photodiode sees)
%     row 2  |P_{m+1} - P_m|       (amplitude differential, direct detection)
%     row 3  |dL|                  (phase-based, coherent detection)
%   Figure 2: zoom +-100 m around each event, signed dL [nm]
%
%   Saves 11_waterfall_baseline_vs_events.png and 12_waterfall_zoom.png

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions
outdir = 'results';
if ~exist(outdir, 'dir'), mkdir(outdir); end
nm = 1e9;

%% ===================== simulate both cases =====================
P   = params;
F   = fiber_model(P);
ev  = define_events(P);
ev0 = ev([]);                          % empty scenario = fiber at rest
Ne  = numel(ev);

fprintf('\n--- BASELINE (no events) ---\n');
Wb = simulate_waterfall(P, F, ev0);
fprintf('\n--- WITH EVENTS ---\n');
We = simulate_waterfall(P, F, ev);

% Direct detection: raw power and amplitude differential
Db   = detector(P, Wb, 'direct');
De   = detector(P, We, 'direct');
rawb = Db.Y;                    rawe = De.Y;
difb = abs(diff(Db.Y, 1, 2));   dife = abs(diff(De.Y, 1, 2));
clear Db De

% Coherent detection + phase processing
Rb = process_das(P, detector(P, Wb, 'coherent'));
Re = process_das(P, detector(P, We, 'coherent'));
clear Wb We

%% ===================== display helpers =====================
blk      = 10;
poolmax  = @(X) squeeze(max (reshape(X(1:floor(size(X,1)/blk)*blk, :), blk, [], size(X,2)), [], 1));
poolmean = @(X) squeeze(mean(reshape(X(1:floor(size(X,1)/blk)*blk, :), blk, [], size(X,2)), 1));
zb  = P.z (round(blk/2) : blk : floor(P.Nz/blk)*blk) / 1e3;
zbR = Re.z(round(blk/2) : blk : floor(numel(Re.z)/blk)*blk) / 1e3;
t   = P.t_slow;

%% ===================== Figure 1: full fiber =====================
fig1 = figure('Name','Baseline vs events','Position',[40 30 1150 900]);

rows = { ...
  {10*log10(poolmean(rawb).'/1e-3), 10*log10(poolmean(rawe).'/1e-3), zb,  t,        [-60 -40], 'raw power [dBm]'}, ...
  {10*log10(poolmax(difb).'/1e-9),  10*log10(poolmax(dife).'/1e-9),  zb,  t(2:end), [-15 15],  '|P_{m+1}-P_m| [dB re 1 nW]'}, ...
  {poolmax(abs(Rb.dL)).'*nm,        poolmax(abs(Re.dL)).'*nm,        zbR, t,        [0 60],    '|dL| [nm] (phase)'} };
hdr = {'BASELINE (no events)', 'WITH EVENTS'};

for r = 1:3
    for c = 1:2
        subplot(3, 2, (r-1)*2 + c);
        imagesc(rows{r}{3}, rows{r}{4}, rows{r}{c});
        axis xy; colorbar; clim(rows{r}{5});
        xlabel('distance [km]'); ylabel('time [s]');
        title(sprintf('%s: %s', hdr{c}, rows{r}{6}));
        if c == 2 && r > 1
            for i = 1:Ne
                text(ev(i).z0/1e3 + 0.15, t(end)*0.93, ev(i).type, ...
                     'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end
end
save_fig(fig1, outdir, '11_waterfall_baseline_vs_events');
clear rawb rawe difb dife

%% ===================== Figure 2: zoom on each event =====================
% Signed dL with a blue-white-red map: shows the oscillation itself
cmap = [linspace(0,1,128)' linspace(0,1,128)' ones(128,1);
        ones(128,1) linspace(1,0,128)' linspace(1,0,128)'];

fig2 = figure('Name','Zoom on events','Position',[60 30 1100 950]);
for i = 1:Ne
    win = abs(Re.z - ev(i).z0) <= 100;
    zw  = Re.z(win) - ev(i).z0;                     % distance from event [m]
    lim = max(20, ceil(max(abs(ev(i).dL))*nm/10)*10);

    subplot(Ne, 2, 2*i-1);
    imagesc(zw, t, Rb.dL(win, :).' * nm);
    axis xy; colorbar; clim([-lim lim]); colormap(gca, cmap);
    ylabel('time [s]');
    title(sprintf('BASELINE @ %.0f m', ev(i).z0));

    subplot(Ne, 2, 2*i);
    imagesc(zw, t, Re.dL(win, :).' * nm);
    axis xy; colorbar; clim([-lim lim]); colormap(gca, cmap);
    title(sprintf('%s @ %.0f m', ev(i).name, ev(i).z0));
    if i == Ne
        subplot(Ne, 2, 2*i-1); xlabel('distance from event [m]');
        subplot(Ne, 2, 2*i);   xlabel('distance from event [m]');
    end
end
save_fig(fig2, outdir, '12_waterfall_zoom');

%% ===================== detection margin =====================
% Threshold = highest activity found ANYWHERE in the baseline:
% anything above it cannot be explained by noise alone.
thr = max(Rb.act);
fprintf('\n------ detection margin (phase activity, > 5 Hz) ------\n');
fprintf('Baseline: median %.2f nm, max %.2f nm  -> threshold\n', ...
        median(Rb.act)*nm, thr*nm);
fprintf('%-28s %10s %10s %10s\n', 'event', 'peak [nm]', 'margin', 'detected');
for i = 1:Ne
    pk = max(Re.act(abs(Re.z - ev(i).z0) < 60));
    fprintf('%-28s %10.2f %7.1f dB %10s\n', ev(i).name, pk*nm, ...
            20*log10(pk/thr), string(pk > thr));
end
falses = sum(Re.act > thr & all(abs(Re.z(:) - [ev.z0]) > 60, 2));
fprintf('Positions above threshold away from events: %d (false alarms)\n', falses);
fprintf('-------------------------------------------------------\n');

%% ===================== local function =====================
function save_fig(fig, outdir, name)
    file = fullfile(outdir, [name '.png']);
    try
        exportgraphics(fig, file, 'Resolution', 200);
    catch
        print(fig, file, '-dpng', '-r200');
    end
end