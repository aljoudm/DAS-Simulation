function R = process_das(P, Dt)
% PROCESS_DAS  Recovers the local elongation dL(z,t) from coherent data.
%
%   R = process_das(P, Dt)     Dt from detector(P, W, 'coherent')
%
%   Steps (all in the complex domain, angle taken only at the end):
%     1) reference removal    A(z,m) = Y(z,m) * conj(Y(z,1))
%        -> removes the static speckle phase; keeps the change since pulse 1
%           (no accumulation over time -> no phase drift)
%     2) gauge differential   Z(z,m) = A(z+G,m) * conj(A(z,m))
%        -> removes the phase accumulated from events UPSTREAM of z,
%           keeps only what happened between z and z+G
%     3) amplitude-weighted spatial sum over one pulse length (Nw samples)
%        -> |Z| ~ |Y|^4, so fading points (|Y| ~ 0) get almost no weight
%     4) dL = angle(Z) / k_strain
%
%   Limitation: the local phase change must stay within +-pi,
%   i.e. |dL| < pi / k_strain  (~338 nm here).
%
%   Output struct R:
%     R.dL     local elongation [m]   [(Nz-G) x Npulses]  (single)
%     R.z      position of each gauge center [m]
%     R.t      slow-time axis [s]
%     R.rms    std of dL over time per position [m]
%     R.act    activity: std of dL after removing < ~5 Hz [m]
%              (used to LOCATE events, insensitive to slow drifts)

if ~strcmp(Dt.mode, 'coherent')
    error('process_das:mode', 'Phase processing needs coherent detection.');
end

G  = P.G;
Nw = P.Nw;
Y  = Dt.Y;

% 1) reference removal (pulse 1)
A = Y .* conj(Y(:, 1));

% 2) gauge differential
Z = A(G+1:end, :) .* conj(A(1:end-G, :));
clear A

% 3) amplitude-weighted sum over one pulse length
Z = conv2(Z, ones(Nw, 1, 'single'), 'same');

% 4) phase -> elongation
R.dL  = angle(Z) / P.k_strain;
clear Z
R.z   = Dt.z(1:end-G) + P.gauge/2;
R.t   = Dt.t;
R.rms = std(R.dL, 0, 2);

% Activity map: remove slow components (< ~5 Hz) before the rms
K     = round(P.PRF / 5);
R.act = std(R.dL - movmean(R.dL, K, 2), 0, 2);

fprintf('process_das: gauge = %.0f m (%d samples), window = %d samples\n', ...
        P.gauge, G, Nw);
fprintf('process_das: max measurable |dL| = %.0f nm\n', pi/P.k_strain*1e9);
fprintf('process_das: background activity ~ %.2f nm rms\n', median(R.act)*1e9);
end