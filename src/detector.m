function Dt = detector(P, W, mode)
% DETECTOR  Converts the optical field into a measured (noisy) signal.
%
%   Dt = detector(P, W)              coherent detection (default)
%   Dt = detector(P, W, 'coherent')  measures amplitude AND phase (I/Q)
%   Dt = detector(P, W, 'direct')    measures power only, |E|^2
%
%   Noise model:
%     P.SNR_dB is defined at the fiber start, relative to the MEAN
%     backscattered power P_bs0. The noise level is the same for every
%     sample, so the LOCAL SNR drops with attenuation and collapses at
%     fading points (where |E| is close to zero).
%
%     coherent:  Y = E + n,      n complex Gaussian, E|n|^2 = sigma2
%     direct:    Y = |E|^2 + n,  n real Gaussian, std = sigma2
%
%   Output struct Dt:
%     Dt.mode     'coherent' or 'direct'
%     Dt.Y        measured signal [Nz x Npulses] (complex or real, single)
%     Dt.sigma2   noise power [W]
%     Dt.z, Dt.t  axes

if nargin < 3, mode = 'coherent'; end

% Noise is a property of the DETECTOR, not of the pulse: it is fixed by the
% backscatter of a reference pulse (tau_ref). A longer pulse then gives
% more signal over the same noise, i.e. a higher SNR.
if isfield(P, 'tau_ref'), tau_ref = P.tau_ref; else, tau_ref = P.tau; end
P_ref     = P.P0 * P.S * P.alpha_s * (P.vg * tau_ref / 2);
Dt.sigma2 = P_ref / 10^(P.SNR_dB/10);
Dt.mode   = lower(mode);
Dt.z      = W.z;
Dt.t      = W.t;

s_old = rng;
rng(P.seed + 2);                    % separate random stream for noise

sz = size(W.E);
switch Dt.mode
    case 'coherent'
        n    = sqrt(Dt.sigma2/2) * complex(randn(sz,'single'), randn(sz,'single'));
        Dt.Y = W.E + n;

    case 'direct'
        n    = Dt.sigma2 * randn(sz, 'single');
        Dt.Y = abs(W.E).^2 + n;

    otherwise
        error('detector:mode', 'Unknown mode "%s". Use coherent or direct.', mode);
end

rng(s_old);
fprintf('detector: %s, SNR = %.0f dB at start, noise = %.3f nW\n', ...
        Dt.mode, P.SNR_dB, Dt.sigma2*1e9);
end