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
%   Saves 11_waterfall_baseline_vs_events and 12_waterfall_zoom (png 300 dpi + pdf)

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions
outdir = results_dir();
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

%% ===================== Figure 1: full fiber + zoom on each event =====================
% Same data as before; presentation only (report style, png 300 dpi + pdf).
fig_style();
lett = {'(a)','(b)','(c)','(d)','(e)','(f)','(g)','(h)','(i)','(j)'};
fig1 = figure('Name','Baseline vs events','Position',[40 30 1100 1150]);
tl   = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

rows = { ...
  {10*log10(poolmean(rawb).'/1e-3), 10*log10(poolmean(rawe).'/1e-3), zb,  t,        [-60 -40], 'raw power [dBm]'}, ...
  {10*log10(poolmax(difb).'/1e-9),  10*log10(poolmax(dife).'/1e-9),  zb,  t(2:end), [-15 15],  '|P_{m+1} - P_m| [dB re 1 nW]'}, ...
  {poolmax(abs(Rb.dL)).'*nm,        poolmax(abs(Re.dL)).'*nm,        zbR, t,        [0 60],    'peak |\DeltaL| [nm]'} };
hdr = {'baseline (no events)', 'with events'};

for r = 1:3
    nest = tiledlayout(tl, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    nest.Layout.Tile = r;
    for c = 1:2
        ax = nexttile(nest);
        imagesc(ax, rows{r}{3}, rows{r}{4}, rows{r}{c});
        axis(ax, 'xy'); clim(ax, rows{r}{5}); grid(ax, 'off');
        xlabel(ax, 'distance [km]');
        if c == 1, ylabel(ax, 'time [s]'); else, set(ax, 'YTickLabel', []); end
        if c == 2, hold(ax, 'on'); mark_events(ax, ev, rows{r}{4}(end), r > 1); end
        panel_label(ax, sprintf('%s %s', lett{2*r-2+c}, hdr{c}));
    end
    cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Label.String = rows{r}{6};   % one colour scale per row
end
Zs = cell(1, Ne); zw = cell(1, Ne);
for i = 1:Ne
    win   = abs(Re.z(:) - ev(i).z0) <= 100;
    zw{i} = Re.z(win) - ev(i).z0;
    Zs{i} = abs(double(Re.dL(win, :))).' * nm;
end
plot_event_zooms(tl, 4, Zs, zw, t, ev, [0 60], [], '|\DeltaL| [nm]', lett(7:10));
save_fig_hq(fig1, outdir, '11_waterfall_baseline_vs_events');
clear rawb rawe difb dife Zs

%% ===================== Figure 2: zoom on each event =====================
% Signed dL with a blue-white-red map: shows the oscillation itself.
% ONE colour scale for all rows (same units), set by the largest injected amplitude.
cmap = [linspace(0,1,128)' linspace(0,1,128)' ones(128,1);
        ones(128,1) linspace(1,0,128)' linspace(1,0,128)'];
lim  = ceil(max(arrayfun(@(e) max(abs(e.dL)), ev))*nm/10)*10;

fig2 = figure('Name','Zoom on events','Position',[60 30 1000 1000]);
tl2  = tiledlayout(Ne, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:Ne
    win = abs(Re.z - ev(i).z0) <= 100;
    zw  = Re.z(win) - ev(i).z0;                     % distance from event [m]
    for c = 1:2
        ax = nexttile(tl2);
        if c == 1, D = Rb.dL(win, :); lbl = 'baseline'; else, D = Re.dL(win, :); lbl = ev(i).type; end
        imagesc(ax, zw, t, D.' * nm);
        axis(ax, 'xy'); clim(ax, [-lim lim]); colormap(ax, cmap); grid(ax, 'off');
        xticks(ax, -100:50:100);
        if c == 1, ylabel(ax, 'time [s]'); else, set(ax, 'YTickLabel', []); end
        if i == Ne, xlabel(ax, 'distance from event [m]'); else, set(ax, 'XTickLabel', []); end
        panel_label(ax, sprintf('(%c) %s, %.0f km', char(96 + 2*i - 2 + c), lbl, ev(i).z0/1e3));
    end
end
cb = colorbar(ax); cb.Layout.Tile = 'east'; cb.Label.String = '\DeltaL [nm]';
save_fig_hq(fig2, outdir, '12_waterfall_zoom');

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

