function T = simulate_trace(P, F, h)
% SIMULATE_TRACE  One phi-OTDR trace (one pulse) arriving at the detector.
%
%   T = simulate_trace(P, F)      trace of the fiber at rest (uses F.h0)
%   T = simulate_trace(P, F, h)   trace with a modified impulse response h
%                                 (used later to insert vibration events)
%
%   Model:
%     1) apply round-trip field attenuation   x(z) = h(z) * exp(-alpha z)
%     2) causal convolution with the pulse    y(z) = sum_m x(z-m) p(m)
%        -> at each instant, the detector sees the COHERENT sum of all
%           scatterers currently inside the pulse (= interference)
%     3) sample with the ADC (keep every os-th fine sample)
%
%   Output struct T:
%     T.E    complex field at the detector [sqrt(W)]   (Nz x 1)
%     T.Pw   optical power |E|^2 [W]                   (Nz x 1)
%     T.z    distance axis [m]                         (1 x Nz)

if nargin < 1, P = params();       end
if nargin < 2, F = fiber_model(P); end
if nargin < 3, h = F.h0;           end

p = pulse(P);

% 1) attenuation
x = h(:) .* F.att;

% 2) causal convolution (filter keeps the same length as x)
y = filter(p, 1, x);

% 3) ADC sampling
T.E  = y(1:P.os:end);
T.E  = T.E(1:P.Nz);
T.Pw = abs(T.E).^2;
T.z  = P.z;
end