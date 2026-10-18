function animate_das(opts)
% ANIMATE_DAS  3D animation of the DAS principle, driven by the real model.
%
%   animate_das            default scenario (digging, 150 nm)
%   animate_das(opts)      opts.name, opts.w_ev [m], opts.dL_max [m],
%                          opts.save_video (true/false)
%
%   3D view : red pulse travels forward; scatterers it crosses flash
%             (yellow) and send light back (cyan). The CYAN RING shows where
%             the light reaching the detector NOW comes from: z = c t / 2n
%             (half the pulse distance, because light goes AND returns).
%   Bottom  : (1) detector trace, (2) change vs fiber at rest, (3) waterfall.
%             All three are revealed at the cyan-ring position, so they are
%             synchronized with the 3D view.
%
%   Pulse 1 = fiber at rest (reference). Pulses 2.. = fiber vibrating.
%   Visual exaggerations only: fiber thickness, deformation, slowed time.
%   Trace values come from simulate_trace (same physics as the simulator).
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions

%% ======================= settings =======================
if nargin < 1, opts = struct(); end
ev_name    = get_opt(opts, 'name',       'Digging');
w_ev       = get_opt(opts, 'w_ev',       6);        % stretched length [m]
dL_max     = get_opt(opts, 'dL_max',     150e-9);   % peak elongation [m]
SAVE_VIDEO = get_opt(opts, 'save_video', true);
L_vis      = 150;       % fiber section shown [m]
z_ev       = 100;       % event position [m]
N_anim     = 7;         % pulses animated (1 = rest, 2..7 = vibrating)
STEP_FIRST = 1.5;       % light travel per frame [m], first pulse (slow)
STEP_NEXT  = 4;         % later pulses

outdir = 'results';
if ~exist(outdir, 'dir'), mkdir(outdir); end

%% ======================= physics =======================
P = params(struct('L', L_vis, 'Npulses', N_anim));
F = fiber_model(P);

ev.name  = ev_name;
ev.type  = lower(ev_name);
ev.z0    = z_ev;
ev.w     = w_ev;
ev.dL    = zeros(1, N_anim);
ev.dL(2:end) = dL_max * cos(2*pi*(0:N_anim-2)/6);   % rest, then vibrating
ev.phi_t = P.k_strain * ev.dL;
ev.ramp  = min(max((P.z_fine(:) - (z_ev - w_ev/2)) / w_ev, 0), 1);

T0  = simulate_trace(P, F);            % fiber at rest
Tr0 = T0.Pw * 1e9;
Tr  = zeros(P.Nz, N_anim);
for m = 1:N_anim
    T = simulate_trace(P, F, apply_event(F, ev, m));
    Tr(:, m) = T.Pw * 1e9;
end
dTr    = abs(Tr - Tr0);                 % change vs rest [nW]
dP_max = max(max(dTr(:)), 1e-3);
z_aff  = [z_ev - w_ev/2, z_ev + w_ev/2 + P.dz_res];   % where the trace changes

vg = P.vg;
Lp = vg * P.tau;                        % physical pulse length (~20 m)

%% ======================= style =======================
bg   = [0.05 0.06 0.10];   fg   = [0.92 0.93 0.95];   dim = [0.60 0.63 0.70];
cyan = [0.30 0.90 1.00];   red  = [1.00 0.25 0.20];   org = [1.00 0.55 0.15];

fig = figure('Name', 'DAS principle - animation', 'Color', bg, ...
             'Position', [40 40 1280 720], 'MenuBar', 'none', 'ToolBar', 'none', ...
             'Resize', 'off');
hT1 = annotation(fig, 'textbox', [0.01 0.945 0.98 0.045], 'String', '', 'Color', fg, ...
    'EdgeColor', 'none', 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
hT2 = annotation(fig, 'textbox', [0.01 0.900 0.98 0.045], 'String', '', 'Color', [0.80 0.86 0.95], ...
    'EdgeColor', 'none', 'FontSize', 11, 'HorizontalAlignment', 'center');

%% ======================= 3D fiber =======================
ax3 = axes('Parent', fig, 'Position', [0.00 0.40 1.00 0.50], 'Color', bg);
hold(ax3, 'on'); axis(ax3, 'off');

r_core = 1;  r_clad = 2.5;
th = linspace(0, 2*pi, 28);
xs = linspace(0, L_vis, 400)';
[TH, XX] = meshgrid(th, xs);
hcl = surf(ax3, XX, r_clad*cos(TH), r_clad*sin(TH), ...
    'FaceColor', [0.7 0.8 1], 'FaceAlpha', 0.08, 'EdgeColor', 'none');
hco = surf(ax3, XX, r_core*cos(TH), r_core*sin(TH), ...
    'FaceColor', [0.2 0.75 1], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

xe = linspace(z_ev - w_ev, z_ev + w_ev, 40)';
[THe, XXe] = meshgrid(th, xe);
hev = surf(ax3, XXe, 1.04*r_clad*cos(THe), 1.04*r_clad*sin(THe), ...
    'FaceColor', org, 'FaceAlpha', 0.35, 'EdgeColor', 'none');

in_vis = F.z_k < L_vis;                 % real scatterers from fiber_model
zk  = F.z_k(in_vis);
rrn = abs(F.r_k(in_vis));  rrn = rrn / max(rrn);
nz  = numel(zk);
s_old = rng; rng(7);
ang = 2*pi*rand(nz,1);  rad = 0.8*r_core*sqrt(rand(nz,1));
rng(s_old);
ys = rad .* cos(ang);  zs = rad .* sin(ang);
S0 = 2 + 14*rrn.^2;
C0 = repmat([0.42 0.44 0.52], nz, 1);
hs = scatter3(ax3, zk, ys, zs, S0, C0, 'filled');

hp   = surf(ax3, zeros(2), zeros(2), zeros(2), 'FaceColor', red, ...
            'FaceAlpha', 0.9, 'EdgeColor', 'none', 'Visible', 'off');
hpl  = text(ax3, 0, 0, 4.3, 'laser pulse', 'Color', red, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'Visible', 'off');
hpar = scatter3(ax3, NaN, NaN, NaN, 10, cyan, 'filled');

cth  = linspace(0, 2*pi, 60);
hring = plot3(ax3, nan(1,60), 1.3*r_clad*cos(cth), 1.3*r_clad*sin(cth), ...
              'Color', cyan, 'LineWidth', 2.5);
hrl   = text(ax3, 0, 0, -4.6, 'echo arriving now', 'Color', cyan, ...
             'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Visible', 'off');

draw_box(ax3, -13, -3, 3);
text(ax3, -8, 0, 5.2, {'Interrogator', '(laser + detector)'}, 'Color', fg, ...
     'HorizontalAlignment', 'center', 'FontSize', 10);
text(ax3, z_ev, 0, 5.4, ['EVENT: ' ev_name], 'Color', org, ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 11);
for xx = 25:25:L_vis
    text(ax3, xx, 0, -6.2, sprintf('%d m', xx), 'Color', dim, ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
end
text(ax3, 1, 0, -6.2, '0 m', 'Color', dim, 'HorizontalAlignment', 'left', 'FontSize', 9);

light(ax3, 'Position', [50 -60 80], 'Style', 'infinite');
lighting(ax3, 'gouraud');
daspect(ax3, [5 1 1]);
xlim(ax3, [-15 L_vis + 3]); ylim(ax3, [-5 5]); zlim(ax3, [-7 6]);
view(ax3, -10, 12);

%% ======================= bottom panels =======================
yl1 = [0 1.1*max(Tr(:))];
yl2 = [0 1.15*dP_max];

% (1) detector trace
axT = axes('Parent', fig, 'Position', [0.05 0.08 0.27 0.25]);
style_ax(axT, bg, fg, dim);
patch(axT, z_aff([1 2 2 1]), yl1([1 1 2 2]), org, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
hprev = plot(axT, NaN, NaN, 'Color', [0.55 0.55 0.6], 'LineWidth', 1);
htr   = plot(axT, NaN, NaN, 'Color', cyan, 'LineWidth', 1.6);
hcT   = plot(axT, [0 0], yl1, '--', 'Color', cyan, 'LineWidth', 1);
xlim(axT, [0 L_vis]); ylim(axT, yl1);
xlabel(axT, 'distance z [m]'); ylabel(axT, 'power [nW]');
title(axT, '(1) Detector trace', 'Color', fg);
legend(axT, [hprev htr], {'previous pulse', 'current pulse'}, 'TextColor', fg, ...
       'Color', bg, 'EdgeColor', dim, 'FontSize', 8, 'Location', 'northwest');

% (2) change vs rest
axD = axes('Parent', fig, 'Position', [0.38 0.08 0.27 0.25]);
style_ax(axD, bg, fg, dim);
patch(axD, z_aff([1 2 2 1]), yl2([1 1 2 2]), org, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
hd  = plot(axD, NaN, NaN, 'Color', org, 'LineWidth', 1.8);
hcD = plot(axD, [0 0], yl2, '--', 'Color', cyan, 'LineWidth', 1);
hnote = text(axD, L_vis/2, mean(yl2), {'Pulse 1 = fiber at rest (reference)', 'nothing has changed yet'}, ...
             'Color', dim, 'HorizontalAlignment', 'center', 'FontSize', 10);
xlim(axD, [0 L_vis]); ylim(axD, yl2);
xlabel(axD, 'distance z [m]'); ylabel(axD, '|P - P_{rest}| [nW]');
title(axD, '(2) Change vs fiber at rest = the EVENT', 'Color', fg);

% (3) waterfall
axW = axes('Parent', fig, 'Position', [0.71 0.08 0.24 0.25]);
style_ax(axW, bg, fg, dim);
WF  = zeros(N_anim, P.Nz);
hwf = imagesc(axW, P.z, 1:N_anim, WF);
axis(axW, 'xy'); colormap(axW, hot); clim(axW, [0 dP_max]);
hcW = plot(axW, [0 0], [0.5 N_anim+0.5], '--', 'Color', cyan, 'LineWidth', 1);
xlim(axW, [0 L_vis]); ylim(axW, [0.5 N_anim+0.5]); yticks(axW, 1:N_anim);
cb = colorbar(axW); cb.Color = fg; cb.Label.String = 'nW';
xlabel(axW, 'distance z [m]'); ylabel(axW, 'pulse #');
title(axW, '(3) Waterfall: one row per pulse', 'Color', fg);

%% ======================= video =======================
vid = [];
if SAVE_VIDEO
    try
        vid = VideoWriter(fullfile(outdir, 'das_animation.mp4'), 'MPEG-4');
    catch
        vid = VideoWriter(fullfile(outdir, 'das_animation.avi'), 'Motion JPEG AVI');
    end
    vid.FrameRate = 30;
    open(vid);
end
fsz = [];                               % frame size, fixed by the first frame

%% ======================= animation =======================
for m = 1:N_anim
    % the fiber is frozen during one pulse (light >> vibration speed)
    a  = 1.8 * ev.dL(m) / dL_max;
    yo = @(x) a * (abs(x - z_ev) < w_ev) .* cos(pi*(x - z_ev)/(2*w_ev)).^2;
    set(hcl, 'YData', r_clad*cos(TH) + yo(XX));
    set(hco, 'YData', r_core*cos(TH) + yo(XX));
    set(hev, 'YData', 1.04*r_clad*cos(THe) + yo(XXe));
    set(hs,  'YData', ys + yo(zk));
    if m > 1, set(hprev, 'XData', P.z, 'YData', Tr(:, m-1)); set(hnote, 'Visible', 'off'); end
    set(htr, 'XData', NaN, 'YData', NaN);
    set(hd,  'XData', NaN, 'YData', NaN);

    if m == 1, step = STEP_FIRST; else, step = STEP_NEXT; end
    dt   = step / vg;
    tEnd = 2*L_vis/vg + P.tau;
    px = zeros(0,1); py = px; pz = px;

    for tt = 0:dt:tEnd
        % ---- forward pulse ----
        xf = vg * tt;
        x1 = max(0, xf - Lp);  x2 = min(L_vis, xf);
        if x2 > x1
            xp = linspace(x1, x2, 12)';
            [THp, XP] = meshgrid(th, xp);
            set(hp, 'XData', XP, 'YData', 1.05*r_core*cos(THp) + yo(XP), ...
                    'ZData', 1.05*r_core*sin(THp), 'Visible', 'on');
            set(hpl, 'Position', [(x1+x2)/2 0 4.3], 'Visible', 'on');
            inside = zk >= x1 & zk <= x2;
        else
            set(hp, 'Visible', 'off'); set(hpl, 'Visible', 'off');
            inside = false(nz, 1);
        end

        % ---- scattering ----
        C = C0;  C(inside, :) = repmat([1 0.95 0.3], nnz(inside), 1);
        S = S0;  S(inside) = 3 * S0(inside);
        set(hs, 'CData', C, 'SizeData', S);
        em = inside & (rand(nz,1) < 0.12*rrn.^2);
        px = [px; zk(em)]; py = [py; ys(em) + yo(zk(em))]; pz = [pz; zs(em)];
        px = px - step;
        keep = px > 0;  px = px(keep); py = py(keep); pz = pz(keep);
        set(hpar, 'XData', px, 'YData', py, 'ZData', pz);

        % ---- echo position: light reaching the detector NOW ----
        zr = vg * tt / 2;
        if zr <= L_vis
            set(hring, 'XData', zr*ones(1,60));
            set(hrl, 'Position', [zr 0 -4.6], 'Visible', 'on');
        else
            set(hring, 'XData', nan(1,60)); set(hrl, 'Visible', 'off');
        end
        zc = min(zr, L_vis);
        set([hcT hcD], 'XData', [zc zc]);  set(hcW, 'XData', [zc zc]);

        % ---- reveal the data up to the echo position ----
        k = P.z <= zr;
        set(htr, 'XData', P.z(k), 'YData', Tr(k, m));
        set(hd,  'XData', P.z(k), 'YData', dTr(k, m));
        WF(m, k) = dTr(k, m).';
        set(hwf, 'CData', WF);

        % ---- explanation ----
        set(hT1, 'String', sprintf(['Pulse %d of %d   |   t = %4.0f ns after launch ' ...
             '(slowed ~10^9 x)   |   fiber state: dL = %+.0f nm'], ...
             m, N_anim, tt*1e9, ev.dL(m)*1e9));
        if zr >= z_aff(1) && zr <= z_aff(2) && m > 1
            msg = ['The echo from the EVENT is arriving: its phase changed, so the speckle ' ...
                   'pattern - and the trace - changes ONLY here (orange zone).'];
        elseif m == 1 && x2 > x1
            msg = ['Pulse 1 = REFERENCE, fiber at rest. Tall peaks in the trace are speckle ' ...
                   '(random interference), NOT events. They repeat identically every pulse.'];
        elseif x2 > x1
            msg = ['Cyan ring: where the light reaching the detector NOW comes from, ' ...
                   'z = c t / 2n (half the pulse distance: light goes AND returns).'];
        else
            msg = 'The pulse has left this section; echoes from the far points are still travelling back.';
        end
        set(hT2, 'String', msg);

        drawnow;
        fsz = put_frame(vid, fig, fsz);
    end

    % ---- between pulses ----
    set(hpar, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
    set(hs, 'CData', C0, 'SizeData', S0);
    set(hring, 'XData', nan(1,60)); set(hrl, 'Visible', 'off');
    if m < N_anim
        set(hT2, 'String', sprintf(['Next pulse 1 ms later: the event has moved the fiber ' ...
            '(dL = %+.0f nm). Light is ~10^6 x faster than the vibration, so each pulse ' ...
            'sees a frozen fiber.'], ev.dL(m+1)*1e9));
    else
        set(hT2, 'String', ['Done: the trace looks random, but its CHANGE between pulses ' ...
            'appears only at the event. That is how DAS locates it.']);
    end
    for h = 1:30
        drawnow;
        fsz = put_frame(vid, fig, fsz);
    end
end

if ~isempty(vid)
    close(vid);
    fprintf('Video saved: %s\n', fullfile(vid.Path, vid.Filename));
end
end

%% ======================= local functions =======================
function style_ax(ax, bg, fg, dim)
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    set(ax, 'Color', bg, 'XColor', dim, 'YColor', dim, 'GridColor', dim, ...
            'GridAlpha', 0.25, 'FontSize', 9);
    ax.Title.Color = fg;  ax.XLabel.Color = fg;  ax.YLabel.Color = fg;
end

function draw_box(ax, x0, x1, h)
    V  = [x0 -h -h; x1 -h -h; x1 h -h; x0 h -h; x0 -h h; x1 -h h; x1 h h; x0 h h];
    Fc = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
    patch(ax, 'Vertices', V, 'Faces', Fc, 'FaceColor', [0.30 0.32 0.40], ...
          'EdgeColor', [0.7 0.7 0.75], 'FaceAlpha', 0.95);
end

function fsz = put_frame(vid, fig, fsz)
% Write one video frame, resized (nearest pixel) to the size of the first
% frame, so a small window change on high-DPI screens cannot stop the video.
    if isempty(vid) || ~isvalid(fig), return; end
    fr  = getframe(fig);
    img = fr.cdata;
    if isempty(fsz), fsz = size(img); end
    if ~isequal(size(img), fsz)
        r = round(linspace(1, size(img,1), fsz(1)));
        c = round(linspace(1, size(img,2), fsz(2)));
        img = img(r, c, :);
    end
    writeVideo(vid, img);
end

function v = get_opt(s, name, default)
    if isfield(s, name), v = s.(name); else, v = default; end
end