function Dt = detector(P, W, mode)
% DETECTOR  Converts the optical field into a measured (noisy) signal.
%
%   Dt = detector(P, W)              coherent detection (default)
%   Dt = detector(P, W, 'coherent')  measures amplitude AND phase (I/Q)
%   Dt = detector(P, W, 'direct')    measures power only, |E|^2
%
%   Noise model:
%     The noise power is P.P_noise (from das_params); P.SNR_dB is the resulting SNR at the fiber start, relative to the MEAN
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

% Noise is a property of the DETECTOR (das_params: P_noise = P_noise_ref*B_rx/B_ref,
% B_rx = 1/tau; Palmieri 2013), NOT a fixed SNR. SNR then follows from signal power.
Dt.sigma2 = P.P_noise;
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