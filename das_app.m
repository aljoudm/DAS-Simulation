function das_app()
% DAS_APP  Interactive DAS simulator: 3D fiber + live equations + data.
%
%   Run from the DAS_Sim folder by typing:  das_app
%
%   Left   : 1) event  2) fiber & laser  3) detector & processing  4) run
%   Middle : inside the fiber (3D), detector trace, WHERE / WHAT / HOW MUCH
%   Right  : result card + governing equations with live values
%
%   Uses the same model as the rest of the simulator
%   (params, fiber_model, simulate_waterfall, detector, process_das).
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));   % model functions

S = struct('ready', false, 'stale', false);     % app state

% ---------------- colors ----------------
C.bg   = [0.94 0.95 0.97];  C.nav  = [0.10 0.17 0.32];  C.acc = [0.16 0.45 0.85];
C.org  = [0.95 0.50 0.10];  C.red  = [0.85 0.20 0.20];  C.grn = [0.10 0.55 0.25];
C.sub  = [0.42 0.45 0.52];  C.cyan = [0.10 0.75 0.90];  C.ylw = [0.85 0.65 0.00];
WIDTH = containers.Map({'walk','dig','vehicle','sine'}, {5, 3, 30, 10});
NAMES = containers.Map({'walk','dig','vehicle','sine'}, {'Walking','Digging','Vehicle','Sine'});
cmap_bwr = [linspace(0,1,128)' linspace(0,1,128)' ones(128,1);
            ones(128,1) linspace(1,0,128)' linspace(1,0,128)'];

%% ============================== window ==============================
fig  = uifigure('Name', 'DAS Simulator', 'Position', [20 30 1600 930], 'Color', C.bg);
main = uigridlayout(fig, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [8 8 8 8], ...
                    'RowSpacing', 8, 'BackgroundColor', C.bg);

% ---------------- header ----------------
hdr = uigridlayout(main, [2 2], 'BackgroundColor', C.nav, 'Padding', [16 4 16 4], ...
                   'RowSpacing', 0, 'ColumnWidth', {'1x', 'fit'}, 'RowHeight', {'1x', '1x'});
uilabel(hdr, 'Text', 'DAS Simulator   |   phi-OTDR Distributed Acoustic Sensing', ...
        'FontSize', 20, 'FontWeight', 'bold', 'FontColor', 'w');
uilabel(hdr, 'Text', 'MATLAB only  -  same physics as main.m', ...
        'FontColor', [0.75 0.80 0.90], 'HorizontalAlignment', 'right');
uilabel(hdr, 'Text', ['1) choose an event    2) set the system    3) Run    ' ...
        '4) read WHERE / WHAT / HOW MUCH  -  and check the physics on the right'], ...
        'FontColor', [0.82 0.86 0.95]);
uilabel(hdr, 'Text', '');

body = uigridlayout(main, [1 3], 'ColumnWidth', {285, '1x', 400}, 'Padding', [0 0 0 0], ...
                    'ColumnSpacing', 8, 'BackgroundColor', C.bg);

%% ============================== left: controls ==============================
left = uigridlayout(body, [4 1], 'RowHeight', {'fit', 'fit', 'fit', '1x'}, ...
                    'Padding', [0 0 0 0], 'RowSpacing', 8, 'BackgroundColor', C.bg);

% ---- 1 event ----
g1 = section(left, '1   EVENT', 6);
uilabel(g1, 'Text', 'Type of disturbance');
ddType = uidropdown(g1, 'Items', {'Walking', 'Digging', 'Vehicle', 'Sine 100 Hz (calibration)'}, ...
    'ItemsData', {'walk', 'dig', 'vehicle', 'sine'}, 'Value', 'dig', ...
    'Tooltip', 'Each type has its own waveform, frequency content and stretched length w');
lblPos = uilabel(g1, 'Text', '');
slPos  = uislider(g1, 'Limits', [0.5 9.5], 'Value', 6, ...
    'Tooltip', 'Distance of the event from the interrogator');
lblA   = uilabel(g1, 'Text', '');
slA    = uislider(g1, 'Limits', [5 300], 'Value', 80, 'MajorTicks', [5 100 200 300], ...
    'Tooltip', 'How much the fiber is stretched at the peak (above ~338 nm the phase wraps)');

% ---- 2 fiber & laser ----
g2 = section(left, '2   FIBER & LASER', 5);
uilabel(g2, 'Text', 'Fiber length');
ddL = uidropdown(g2, 'Items', {'5 km', '10 km', '20 km'}, 'ItemsData', {5e3, 10e3, 20e3}, ...
    'Value', 10e3, 'Tooltip', 'Longer fiber = more attenuation at the far end and lower max PRF');
uilabel(g2, 'Text', 'Pulse width');
ddTau = uidropdown(g2, 'Items', {'25 ns', '50 ns', '100 ns', '200 ns'}, ...
    'ItemsData', {25e-9, 50e-9, 100e-9, 200e-9}, 'Value', 100e-9, ...
    'Tooltip', 'Shorter pulse = finer resolution but less light (lower SNR)');
lblFib = uilabel(g2, 'Text', '', 'WordWrap', 'on', 'FontColor', C.acc, 'FontSize', 11);

% ---- 3 detector & processing ----
g3 = section(left, '3   DETECTOR & PROCESSING', 5);
lblSNR = uilabel(g3, 'Text', '');
slSNR  = uislider(g3, 'Limits', [5 40], 'Value', 30, ...
    'Tooltip', 'Signal-to-noise ratio of the detector at the fiber start (100 ns pulse)');
lblG   = uilabel(g3, 'Text', '');
slG    = uislider(g3, 'Limits', [5 60], 'Value', 20, ...
    'Tooltip', 'Phase is differenced over this length to isolate the local strain');
lblGh  = uilabel(g3, 'Text', '', 'WordWrap', 'on', 'FontSize', 11);

% ---- 4 run ----
g4 = section(left, '4   RUN', 4);
g4.RowHeight = {36, 30, 30, '1x'};
btnRun  = uibutton(g4, 'Text', 'Run simulation', 'FontWeight', 'bold', 'FontSize', 14, ...
    'BackgroundColor', C.acc, 'FontColor', 'w', 'ButtonPushedFcn', @onRun);
btnAnim = uibutton(g4, 'Text', 'Animate the light (3D)', 'Enable', 'off', ...
    'ButtonPushedFcn', @onAnimate);
btnVid  = uibutton(g4, 'Text', 'Record video (new window)', 'ButtonPushedFcn', @onVideo);
lblStat = uilabel(g4, 'Text', 'Set the scenario, then press Run.', 'WordWrap', 'on', ...
    'VerticalAlignment', 'top', 'FontColor', C.sub);

%% ============================== middle: data ==============================
mid = uigridlayout(body, [3 3], 'RowHeight', {'1.25x', '1x', '1x'}, 'Padding', [0 0 0 0], ...
                   'RowSpacing', 8, 'ColumnSpacing', 8, 'BackgroundColor', C.bg);

p3d = uipanel(mid, 'Title', 'INSIDE THE FIBER   (120 m around the event - shapes exaggerated)', ...
    'FontWeight', 'bold', 'BackgroundColor', 'w', 'ForegroundColor', C.nav);
p3d.Layout.Row = 1; p3d.Layout.Column = [1 3];
g3d = uigridlayout(p3d, [2 1], 'RowHeight', {'1x', 20}, 'Padding', [4 2 4 2], ...
                   'RowSpacing', 2, 'BackgroundColor', 'w');
ax3 = uiaxes(g3d);
leg = uigridlayout(g3d, [1 5], 'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'BackgroundColor', 'w');
legend_item(leg, [char(9632) ' laser pulse'],              C.red);
legend_item(leg, [char(9679) ' scatterer hit by the pulse'], C.ylw);
legend_item(leg, [char(9679) ' backscattered light'],       C.cyan);
legend_item(leg, [char(9679) ' scatterer (size = strength)'], C.sub);
legend_item(leg, [char(9632) ' event (stretched fiber)'],   C.org);

axTr  = data_panel(mid, 2, 1,     'DETECTOR TRACE  (one pulse vs theory)');
axAct = data_panel(mid, 2, 2,     'WHERE  -  activity along the fiber');
axSp  = data_panel(mid, 2, 3,     'WHAT  -  frequency signature');
axWf  = data_panel(mid, 3, 1,     'WATERFALL  -  dL around the event');
axRec = data_panel(mid, 3, [2 3], 'HOW MUCH  -  recovered from the light vs injected');

ax3.Color = [0.04 0.05 0.10];
ax3.XColor = 'none'; ax3.YColor = 'none'; ax3.ZColor = 'none';
for axh = [ax3 axTr axAct axSp axWf axRec]
    placeholder(axh);
end

%% ============================== right: result + physics ==============================
right = uigridlayout(body, [2 1], 'RowHeight', {'fit', '1x'}, 'Padding', [0 0 0 0], ...
                     'RowSpacing', 8, 'BackgroundColor', C.bg);

pRes = uipanel(right, 'Title', 'RESULT', 'FontWeight', 'bold', 'BackgroundColor', 'w', ...
               'ForegroundColor', C.nav);
gR = uigridlayout(pRes, [4 4], 'RowHeight', {46, 'fit', 'fit', 'fit'}, ...
                  'ColumnWidth', {'fit', '1x', 'fit', '1x'}, 'BackgroundColor', 'w', ...
                  'RowSpacing', 4, 'ColumnSpacing', 6);
lblVerdict = uilabel(gR, 'Text', 'No result yet', 'FontSize', 22, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [0.88 0.89 0.92], 'FontColor', C.sub);
lblVerdict.Layout.Row = 1; lblVerdict.Layout.Column = [1 4];
mNames = {'Margin over noise', 'Position error', 'Correlation', 'Amplitude ratio', ...
          'Main frequency', 'False alarms'};
valL = gobjects(6, 1);
for i = 1:6
    uilabel(gR, 'Text', mNames{i}, 'FontColor', C.sub);
    valL(i) = uilabel(gR, 'Text', '-', 'FontWeight', 'bold');
end

pEq = uipanel(right, 'Title', 'PHYSICS   (values update live with the settings)', ...
              'FontWeight', 'bold', 'BackgroundColor', 'w', 'ForegroundColor', C.nav);
groups = {'SPATIAL RESOLUTION', 1; 'TIMING', 2; 'BACKSCATTERED LIGHT', 3; ...
          'EVENT  ->  LIGHT', [4 5]; 'NOISE  (computed by Run)', [6 7]; 'PROCESSING', 8};
NEQ  = 8;
nrow = size(groups, 1) + 2*NEQ;
gE = uigridlayout(pEq, [nrow 1], 'RowHeight', repmat({'fit'}, 1, nrow), ...
                  'RowSpacing', 2, 'BackgroundColor', 'w', 'Scrollable', 'on');
eqL = gobjects(NEQ, 1);  txL = gobjects(NEQ, 1);
for gi = 1:size(groups, 1)
    uilabel(gE, 'Text', groups{gi, 1}, 'FontWeight', 'bold', 'FontColor', C.acc, 'FontSize', 11);
    for q = groups{gi, 2}
        eqL(q) = uilabel(gE, 'Interpreter', 'latex', 'Text', ' ', 'FontSize', 15);
        txL(q) = uilabel(gE, 'Text', ' ', 'WordWrap', 'on', 'FontColor', C.sub, 'FontSize', 11);
    end
end

%% ============================== wiring ==============================
slPos.ValueChangingFcn = @(s,e) set_labels(e.Value, [], [], []);
slA.ValueChangingFcn   = @(s,e) set_labels([], e.Value, [], []);
slSNR.ValueChangingFcn = @(s,e) set_labels([], [], e.Value, []);
slG.ValueChangingFcn   = @(s,e) set_labels([], [], [], e.Value);
ctrls = {slPos, slA, slSNR, slG, ddType, ddTau};
for ic = 1:numel(ctrls)
    ctrls{ic}.ValueChangedFcn = @onSetting;
end
ddL.ValueChangedFcn = @onLength;

set_labels([], [], [], []);
update_design();

% ======================================================================
%                             UI HELPERS
% ======================================================================
    function g = section(parent, ttl, nrows)
        p = uipanel(parent, 'Title', ttl, 'FontWeight', 'bold', 'FontSize', 12, ...
                    'BackgroundColor', 'w', 'ForegroundColor', C.nav);
        g = uigridlayout(p, [nrows 1], 'RowHeight', repmat({'fit'}, 1, nrows), ...
                         'RowSpacing', 4, 'BackgroundColor', 'w');
    end

    function ax = data_panel(parent, r, c, ttl)
        p = uipanel(parent, 'Title', ttl, 'FontWeight', 'bold', 'BackgroundColor', 'w', ...
                    'ForegroundColor', C.nav);
        p.Layout.Row = r; p.Layout.Column = c;
        gg = uigridlayout(p, [1 1], 'Padding', [2 2 2 2], 'BackgroundColor', 'w');
        ax = uiaxes(gg);
        ax.FontSize = 10;
    end

    function legend_item(parent, txt, col)
        uilabel(parent, 'Text', txt, 'FontColor', col, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'FontSize', 11);
    end

    function placeholder(ax)
        cla(ax);
        text(ax, 0.5, 0.5, 'press  Run simulation', 'Units', 'normalized', ...
             'HorizontalAlignment', 'center', 'Color', [0.6 0.6 0.65], 'FontSize', 12);
    end

    function set_labels(pos, A, snr, g)
        if isempty(pos), pos = slPos.Value; end
        if isempty(A),   A   = slA.Value;   end
        if isempty(snr), snr = slSNR.Value; end
        if isempty(g),   g   = slG.Value;   end
        lblPos.Text = sprintf('Position:  %.2f km', pos);
        lblA.Text   = sprintf('Peak stretch dL:  %.0f nm', A);
        lblSNR.Text = sprintf('Detector SNR:  %.0f dB', snr);
        lblG.Text   = sprintf('Gauge length:  %.0f m', g);
    end

% ======================================================================
%                              CALLBACKS
% ======================================================================
    function onSetting(~, ~)
        set_labels([], [], [], []);
        mark_stale();
        update_design();
    end

    function onLength(~, ~)
        Lkm = ddL.Value / 1e3;
        slPos.Limits = [0.5 Lkm - 0.5];
        slPos.Value  = min(max(slPos.Value, 0.5), Lkm - 0.5);
        onSetting();
    end

    function mark_stale()
        if S.ready
            S.stale = true;
            lblVerdict.Text = 'Settings changed  -  press Run';
            lblVerdict.BackgroundColor = [0.88 0.89 0.92];
            lblVerdict.FontColor = C.sub;
            lblStat.Text = 'The plots show the PREVIOUS run. Press Run to update.';
        end
    end

    function onRun(~, ~)
        d = uiprogressdlg(fig, 'Title', 'Simulating', 'Indeterminate', 'on');
        btnRun.Enable = 'off';
        try
            type = ddType.Value;
            z0   = slPos.Value * 1e3;
            A    = slA.Value * 1e-9;
            P = params(struct('L', ddL.Value, 'tau', ddTau.Value, ...
                              'SNR_dB', slSNR.Value, 'gauge', slG.Value));
            d.Message = 'Building the fiber (Rayleigh scatterers)...';
            F  = fiber_model(P);
            ev = make_event(P, type, z0, A);

            d.Message = sprintf('Sending %d pulses through %.0f km of fiber...', P.Npulses, P.L/1e3);
            W = simulate_waterfall(P, F, ev);
            [~, im] = max(abs(ev.dL));
            Tr1 = abs(double(W.E(:, im))).^2;

            d.Message = 'Coherent detection + noise...';
            Dc  = detector(P, W, 'coherent');
            iz0 = min(max(round(z0/P.dz_adc) + 1, 6), P.Nz - 5);
            SNRev = 10*log10(mean(abs(double(W.E(iz0-5:iz0+5, :))).^2, 'all') / Dc.sigma2);
            clear W

            d.Message = 'Phase processing...';
            R = process_das(P, Dc);
            clear Dc

            M = metrics(P, ev, R, z0, SNRev);
            S = struct('ready', true, 'stale', false, 'P', P, 'F', F, 'ev', ev, 'R', R, ...
                       'Tr1', Tr1, 'M', M, 'z0', z0, 'A', A, 'im', im);
            draw_all();
            update_design();
            show_result();
            btnAnim.Enable = 'on';
            lblStat.Text = sprintf('Done: %s at %.2f km. Press "Animate" to watch the light.', ...
                                   ev.name, z0/1e3);
        catch err
            uialert(fig, err.message, 'Simulation error');
        end
        btnRun.Enable = 'on';
        close(d);
    end

    function onAnimate(~, ~)
        if ~S.ready, return; end
        btnAnim.Enable = 'off'; btnRun.Enable = 'off';
        P = S.P; ev = S.ev; H = S.h3;
        Lp = P.vg * P.tau;
        sp = max(1, round(P.PRF / (4*max(S.M.fdom, 1))));     % ~4 pulses per period
        ms = max(1, S.im - 2*sp) + (0:7) * sp;
        ms = ms(ms <= P.Npulses);
        step = 4;
        for m = ms
            a  = 1.5 * ev.dL(m) / S.A;
            yo = @(u) a * (abs(u) < H.wv) .* cos(pi*u/(2*H.wv)).^2;
            set(H.cl, 'YData', H.rcl*cos(H.TH) + yo(H.UU));
            set(H.co, 'YData', H.rco*cos(H.TH) + yo(H.UU));
            set(H.ev, 'YData', 1.04*H.rcl*cos(H.THe) + yo(H.UUe));
            set(H.s,  'YData', H.ys + yo(H.uk));
            px = zeros(0,1); py = px; pz = px;
            for uf = -H.half : step : H.half + Lp
                u1 = max(-H.half, uf - Lp);  u2 = min(H.half, uf);
                if u2 > u1
                    up = linspace(u1, u2, 10)';
                    [THp, UP] = meshgrid(H.th, up);
                    set(H.p, 'XData', UP, 'YData', 1.05*H.rco*cos(THp) + yo(UP), ...
                             'ZData', 1.05*H.rco*sin(THp), 'Visible', 'on');
                    set(H.pl, 'Position', [(u1+u2)/2 0 3.8], 'Visible', 'on');
                    in = H.uk >= u1 & H.uk <= u2;
                else
                    set(H.p, 'Visible', 'off'); set(H.pl, 'Visible', 'off');
                    in = false(size(H.uk));
                end
                Cc = H.C0; Cc(in, :) = repmat([1 0.9 0.2], nnz(in), 1);
                Sz = H.S0; Sz(in) = 3*H.S0(in);
                set(H.s, 'CData', Cc, 'SizeData', Sz);
                em = in & (rand(size(H.uk)) < 0.12*H.rrn.^2);
                px = [px; H.uk(em)]; py = [py; H.ys(em) + yo(H.uk(em))]; pz = [pz; H.zs(em)];
                px = px - step;
                keep = px > -H.half;
                px = px(keep); py = py(keep); pz = pz(keep);
                set(H.par, 'XData', px, 'YData', py, 'ZData', pz);
                lblStat.Text = sprintf(['Pulse #%d   (t = %.1f ms)\n' ...
                    'fiber stretched by dL = %+.0f nm\n-> extra phase = %+.2f rad'], ...
                    m, (m-1)/P.PRF*1e3, ev.dL(m)*1e9, ev.phi_t(m));
                drawnow limitrate;
            end
            set(H.par, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            set(H.s, 'CData', H.C0, 'SizeData', H.S0);
        end
        set(H.p, 'Visible', 'off'); set(H.pl, 'Visible', 'off');
        lblStat.Text = ['Each pulse sees the fiber frozen in a different state ' ...
                        '(light is ~10^6 x faster than the vibration).'];
        btnAnim.Enable = 'on'; btnRun.Enable = 'on';
    end

    function onVideo(~, ~)
        opts.name   = NAMES(ddType.Value);
        opts.w_ev   = WIDTH(ddType.Value);
        opts.dL_max = slA.Value * 1e-9;
        lblStat.Text = 'Recording the video in a new window (do not resize it)...';
        drawnow;
        animate_das(opts);
        lblStat.Text = 'Video saved in the results folder.';
    end

% ======================================================================
%                        EQUATIONS AND RESULT
% ======================================================================
    function update_design()
        type = ddType.Value;  w = WIDTH(type);
        A  = slA.Value * 1e-9;  z0 = slPos.Value * 1e3;
        P  = params(struct('L', ddL.Value, 'tau', ddTau.Value, ...
                           'SNR_dB', slSNR.Value, 'gauge', slG.Value));
        nm = 1e9;
        Pbs = P.P0 * P.S * P.alpha_s * P.dz_res * exp(-2*P.alpha*z0);
        need = w + P.dz_res;

        lblFib.Text = sprintf('->  resolution %.1f m   |   max PRF %.1f kHz   |   max vibration %.0f Hz', ...
                              P.dz_res, P.PRF_max/1e3, P.f_vib_max);
        if P.gauge >= need
            lblGh.Text = sprintf('OK: gauge >= w + resolution = %.1f m', need);
            lblGh.FontColor = C.grn;
        else
            lblGh.Text = sprintf('Too short: needs >= %.1f m to capture the whole event', need);
            lblGh.FontColor = C.red;
        end

        set_eq(1, ['\Delta z = \frac{c\,\tau}{2n} = ' f2(P.dz_res) '\ \mathrm{m}'], ...
            sprintf('Two events closer than %.1f m cannot be told apart.', P.dz_res));
        set_eq(2, ['f_{PRF}^{max} = \frac{c}{2nL} = ' f2(P.PRF_max/1e3) '\ \mathrm{kHz}'], ...
            sprintf(['The next pulse must wait for the light to come back. ' ...
                     'Used PRF = %.0f Hz -> vibrations up to %.0f Hz.'], P.PRF, P.f_vib_max));
        set_eq(3, ['P_{bs} = P_0\,S\,\alpha_s\,\Delta z\; e^{-2\alpha z} = ' ...
                   f1(10*log10(Pbs/1e-3)) '\ \mathrm{dBm}'], ...
            sprintf('Mean Rayleigh light coming back from %.2f km (round trip loss %.1f dB).', ...
                    z0/1e3, 2*P.alpha_dB*z0/1e3));
        set_eq(4, ['\Delta\phi = \frac{4\pi n \xi}{\lambda}\,\Delta L = ' ...
                   num2str(P.k_strain*A, '%.3f') '\ \mathrm{rad}'], ...
            sprintf('Phase shift for dL = %.0f nm. Must stay < pi, i.e. dL < %.0f nm.', ...
                    A*nm, pi/P.k_strain*nm));
        set_eq(5, ['\varepsilon = \frac{\Delta L}{w} = ' f1(A/w*1e9) '\ \mathrm{n}\varepsilon'], ...
            sprintf('Strain over the w = %.0f m section: what DAS is really sensitive to.', w));
        if S.ready && ~S.stale
            set_eq(6, ['\mathrm{SNR}_{loc} = \frac{|E|^2}{\sigma^2} = ' f1(S.M.SNRev) '\ \mathrm{dB}'], ...
                'Local SNR at the event: falls with distance and collapses at fading points.');
            set_eq(7, ['\sigma_\phi \approx \frac{1}{\sqrt{2\,\mathrm{SNR}}} = ' ...
                       num2str(S.M.sphi, '%.4f') '\ \mathrm{rad}'], ...
                sprintf('Phase noise at the event = %.2f nm of equivalent dL.', S.M.sphi/P.k_strain*nm));
        else
            set_eq(6, '\mathrm{SNR}_{loc} = \frac{|E|^2}{\sigma^2}', 'Press Run to compute it at the event.');
            set_eq(7, '\sigma_\phi \approx \frac{1}{\sqrt{2\,\mathrm{SNR}}}', 'Press Run to compute it at the event.');
        end
        set_eq(8, ['L_g \geq w + \Delta z = ' f1(need) '\ \mathrm{m}'], ...
            sprintf('Current gauge = %.0f m. A shorter gauge captures only part of the event.', P.gauge));
    end

    function set_eq(q, tex, txt)
        eqL(q).Text = ['$' tex '$'];
        txL(q).Text = txt;
    end

    function show_result()
        M = S.M;
        if M.detect
            lblVerdict.Text = [char(10004) '  DETECTED'];
            lblVerdict.BackgroundColor = [0.86 0.95 0.88]; lblVerdict.FontColor = C.grn;
        else
            lblVerdict.Text = [char(10008) '  NOT DETECTED'];
            lblVerdict.BackgroundColor = [0.98 0.88 0.88]; lblVerdict.FontColor = C.red;
        end
        vals = {sprintf('%+.1f dB', M.margin), sprintf('%.1f m', M.perr), ...
                sprintf('%.3f', M.corr), sprintf('%.2f', M.amp), ...
                sprintf('%.0f Hz', M.fdom), sprintf('%d', M.false)};
        for k = 1:6, valL(k).Text = vals{k}; end
    end

% ======================================================================
%                              DRAWING
% ======================================================================
    function draw_all()
        P = S.P; R = S.R; M = S.M; ev = S.ev; z0 = S.z0; nm = 1e9;
        build3d();

        % ---- trace ----
        cla(axTr); hold(axTr, 'on');
        Pbs0 = P.P0 * P.S * P.alpha_s * P.dz_res;
        Pth  = Pbs0 * exp(-2*P.alpha*P.z);
        plot(axTr, P.z/1e3, 10*log10(S.Tr1/1e-3), 'Color', [0.65 0.65 0.7]);
        plot(axTr, P.z/1e3, 10*log10(Pth/1e-3), 'Color', C.red, 'LineWidth', 1.8);
        hx = xline(axTr, z0/1e3); hx.Color = C.org; hx.LineWidth = 1.5;
        top = 10*log10(Pbs0/1e-3);
        ylim(axTr, [top - 35, top + 8]); xlim(axTr, [0 P.L/1e3]);
        xlabel(axTr, 'distance [km]'); ylabel(axTr, 'power [dBm]');
        grid(axTr, 'on'); box(axTr, 'on');
        legend(axTr, {'measured (speckle)', 'theory', 'event'}, 'Location', 'southwest', 'FontSize', 8);

        % ---- WHERE ----
        cla(axAct); hold(axAct, 'on');
        plot(axAct, R.z/1e3, R.act*nm, 'Color', C.acc);
        hy = yline(axAct, M.thr*nm, '--'); hy.Color = C.red; hy.LineWidth = 1.2;
        hx = xline(axAct, z0/1e3); hx.Color = C.org; hx.LineWidth = 1.5;
        xlim(axAct, [0 P.L/1e3]); grid(axAct, 'on'); box(axAct, 'on');
        xlabel(axAct, 'distance [km]'); ylabel(axAct, 'activity [nm]');
        legend(axAct, {'activity', 'noise threshold', 'true position'}, 'Location', 'northwest', 'FontSize', 8);

        % ---- WHAT ----
        cla(axSp); hold(axSp, 'on');
        plot(axSp, M.f, 20*log10(M.X + 1e-3), 'Color', C.acc);
        hx = xline(axSp, M.fdom, '--', sprintf('%.0f Hz', M.fdom)); hx.Color = C.red;
        xlim(axSp, [0 min(250, P.PRF/2)]); ylim(axSp, [-40 45]);
        grid(axSp, 'on'); box(axSp, 'on');
        xlabel(axSp, 'frequency [Hz]'); ylabel(axSp, 'amplitude [dB re 1 nm]');

        % ---- waterfall ----
        cla(axWf);
        win = abs(R.z - z0) <= 150;
        imagesc(axWf, R.z(win) - z0, R.t, R.dL(win, :).' * nm);
        axis(axWf, 'xy'); colormap(axWf, cmap_bwr);
        lim = max(10, S.A*nm); clim(axWf, [-lim lim]);
        cb = colorbar(axWf); cb.Label.String = 'dL [nm]';
        xlim(axWf, [-150 150]); ylim(axWf, [0 R.t(end)]);
        xlabel(axWf, 'distance from event [m]'); ylabel(axWf, 'time [s]');

        % ---- HOW MUCH ----
        cla(axRec); hold(axRec, 'on');
        plot(axRec, R.t, M.tru, 'k', 'LineWidth', 1.6);
        plot(axRec, R.t, M.est, '--', 'Color', C.red, 'LineWidth', 1.1);
        grid(axRec, 'on'); box(axRec, 'on');
        xlabel(axRec, 'time [s]'); ylabel(axRec, 'dL [nm]');
        legend(axRec, {'injected into the fiber', 'recovered from the light'}, ...
               'Location', 'northeast', 'FontSize', 9);
    end

    function build3d()
        F = S.F; ev = S.ev; z0 = S.z0;
        cla(ax3); hold(ax3, 'on');
        H.half = 60;  H.wv = max(ev.w, 4);
        H.rco = 1;    H.rcl = 2.5;
        H.th = linspace(0, 2*pi, 24);
        u  = linspace(-H.half, H.half, 300)';
        [H.TH, H.UU] = meshgrid(H.th, u);
        ue = linspace(-H.wv, H.wv, 40)';
        [H.THe, H.UUe] = meshgrid(H.th, ue);
        yo = @(uu) 1.5 * (abs(uu) < H.wv) .* cos(pi*uu/(2*H.wv)).^2;    % peak state

        H.cl = surf(ax3, H.UU, H.rcl*cos(H.TH) + yo(H.UU), H.rcl*sin(H.TH), ...
            'FaceColor', [0.7 0.8 1], 'FaceAlpha', 0.10, 'EdgeColor', 'none');
        H.co = surf(ax3, H.UU, H.rco*cos(H.TH) + yo(H.UU), H.rco*sin(H.TH), ...
            'FaceColor', [0.2 0.75 1], 'FaceAlpha', 0.18, 'EdgeColor', 'none');
        H.ev = surf(ax3, H.UUe, 1.04*H.rcl*cos(H.THe) + yo(H.UUe), 1.04*H.rcl*sin(H.THe), ...
            'FaceColor', C.org, 'FaceAlpha', 0.40, 'EdgeColor', 'none');

        sel   = abs(F.z_k - z0) <= H.half;
        H.uk  = F.z_k(sel) - z0;
        H.rrn = abs(F.r_k(sel)); H.rrn = H.rrn / max(H.rrn);
        n     = numel(H.uk);
        s_old = rng; rng(7);
        ang = 2*pi*rand(n,1); rad = 0.8*H.rco*sqrt(rand(n,1));
        rng(s_old);
        H.ys = rad .* cos(ang);  H.zs = rad .* sin(ang);
        H.S0 = 2 + 16*H.rrn.^2;
        H.C0 = repmat([0.55 0.57 0.66], n, 1);
        H.s  = scatter3(ax3, H.uk, H.ys + yo(H.uk), H.zs, H.S0, H.C0, 'filled');
        H.p  = surf(ax3, zeros(2), zeros(2), zeros(2), 'FaceColor', [1 0.25 0.2], ...
                    'FaceAlpha', 0.9, 'EdgeColor', 'none', 'Visible', 'off');
        H.pl = text(ax3, 0, 0, 3.8, 'laser pulse', 'Color', [1 0.35 0.3], ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Visible', 'off');
        H.par = scatter3(ax3, NaN, NaN, NaN, 10, C.cyan, 'filled');

        text(ax3, 0, 0, 5.6, sprintf('%s   (dL = %.0f nm over w = %.0f m)', ev.name, S.A*1e9, ev.w), ...
             'Color', [1 0.65 0.3], 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        text(ax3, -H.half, 0, 4.6, sprintf('<- interrogator is %.2f km this way', z0/1e3), ...
             'Color', [0.8 0.8 0.85], 'FontSize', 9);
        for xx = -60:20:60
            text(ax3, xx, 0, -4.6, sprintf('%+d m', xx), 'Color', [0.65 0.65 0.7], ...
                 'HorizontalAlignment', 'center', 'FontSize', 8);
        end
        daspect(ax3, [5 1 1]);
        xlim(ax3, [-H.half-3 H.half+3]); ylim(ax3, [-5 5]); zlim(ax3, [-5.5 6.5]);
        view(ax3, -10, 12);
        S.h3 = H;
    end

% ======================================================================
%                              METRICS
% ======================================================================
    function M = metrics(P, ev, R, z0, SNRev)
        nm = 1e9;
        cand  = find(abs(R.z - z0) < 60 + P.gauge);
        [pk, k] = max(R.act(cand));
        izr   = cand(k);
        M.est = double(R.dL(izr, :)) * nm;
        M.tru = (ev.dL - ev.dL(1)) * nm;
        c     = corrcoef(M.est, M.tru);
        M.corr = c(1,2);
        M.amp  = std(M.est) / std(M.tru);
        M.perr = R.z(izr) - z0;
        N   = numel(R.t);
        M.f = (0:N/2-1) * P.PRF / N;
        X   = abs(fft(M.est - mean(M.est))) / N * 2;
        M.X = X(1:N/2);
        [~, kk] = max(M.X(2:end));  M.fdom = M.f(kk+1);
        a     = R.act;                                % robust noise threshold
        mad_a = median(abs(a - median(a)));
        M.thr = median(a) + 8 * 1.4826 * mad_a;
        M.detect = pk > M.thr;
        M.margin = 20*log10(pk / M.thr);
        M.false  = sum(a > M.thr & abs(R.z(:) - z0) > 60 + P.gauge);
        M.SNRev  = SNRev;
        M.sphi   = 1 / sqrt(2 * 10^(SNRev/10));
    end
end

% ======================================================================
%                         helper functions
% ======================================================================
function ev = make_event(P, type, z0, A)
% One event of the chosen type (same waveforms as define_events),
% placed at z0 and scaled to a peak elongation A [m].
    P.ev_z = z0 * ones(1, 4);
    all_ev = define_events(P);
    ev = all_ev(strcmp({all_ev.type}, type));
    ev.dL    = ev.dL / max(abs(ev.dL)) * A;
    ev.phi_t = P.k_strain * ev.dL;
    ev.ramp  = min(max((P.z_fine(:) - (z0 - ev.w/2)) / ev.w, 0), 1);
end

function s = f1(x), s = num2str(x, '%.1f'); end
function s = f2(x), s = num2str(x, '%.2f'); end