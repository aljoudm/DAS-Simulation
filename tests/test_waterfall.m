% TEST_WATERFALL  First DAS waterfall: raw vs differential.
%   Run from the DAS_Sim folder by typing:  test_waterfall

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P  = params;
F  = fiber_model(P);
ev = define_events(P);
W  = simulate_waterfall(P, F, ev);

Pw = abs(W.E).^2;                       % power  [Nz x Npulses]
D  = abs(diff(Pw, 1, 2));               % change between consecutive pulses
zk = W.z / 1e3;                         % km

% Max-pooling along distance for DISPLAY only
% (screen has ~500 pixels, data has ~9800 bins -> thin events get skipped)
blk = 10;
nb  = floor(P.Nz / blk);
pool = @(X) squeeze(max(reshape(X(1:nb*blk, :), blk, nb, []), [], 1));
zb  = zk(round(blk/2) : blk : nb*blk);

figure('Name','DAS waterfall','Position',[60 60 1200 800]);

% (a) raw waterfall
subplot(2,2,1);
imagesc(zb, W.t, 10*log10(pool(Pw).'/1e-3));
axis xy; colorbar; clim([-65 -40]);
xlabel('distance [km]'); ylabel('time [s]');
title('(a) Raw power [dBm]: static speckle stripes');

% (b) differential waterfall
subplot(2,2,2);
imagesc(zb, W.t(2:end), pool(D).' * 1e9);
axis xy; colorbar; clim([0 5]);
xlabel('distance [km]'); ylabel('time [s]');
title('(b) |P_{m+1} - P_m| [nW]: only the events remain');
for i = 1:numel(ev)
    text(ev(i).z0/1e3 + 0.15, W.t(end)*0.95, ev(i).type, ...
         'Color','w', 'FontWeight','bold');
end

% (c) localization: peak activity per distance
subplot(2,2,3);
act = max(D, [], 2);
plot(zk, act * 1e9, 'b'); grid on; hold on;
for i = 1:numel(ev), xline(ev(i).z0/1e3, 'r--', ev(i).type); end
xlabel('distance [km]'); ylabel('max |\DeltaP| [nW]');
title('(c) Activity vs distance: WHERE are the events?');

% (d) time signal at each event location
subplot(2,2,4);
hold on;
for i = 1:numel(ev)
    [~, iz] = max(act .* (abs(W.z(:) - ev(i).z0) < 20));  % strongest bin near event
    s = D(iz, :);
    plot(W.t(2:end), s / max(s) + 1.2*(i-1), 'LineWidth', 1);
end
yticks(1.2*(0:numel(ev)-1) + 0.5);
yticklabels({ev.type});
xlabel('time [s]'); grid on;
title('(d) Activity vs time at each event: WHEN?');