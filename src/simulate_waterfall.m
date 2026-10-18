function W = simulate_waterfall(P, F, ev)
% SIMULATE_WATERFALL  Sends Npulses pulses and stores every trace.
%
%   W = simulate_waterfall(P, F, ev)
%
%   For each pulse m (slow time t_m = (m-1)/PRF):
%     1) apply the vibrations at that instant   -> h_m = apply_event(F, ev, m)
%     2) compute the trace at the detector      -> simulate_trace(P, F, h_m)
%     3) store it as column m of the waterfall
%
%   Output struct W:
%     W.E   complex field  [Nz x Npulses]  (rows = distance, cols = time)
%     W.z   distance axis [m]
%     W.t   slow-time axis [s]
%
%   Stored in single precision to halve the memory (~0.16 GB).

if nargin < 1, P  = params();          end
if nargin < 2, F  = fiber_model(P);    end
if nargin < 3, ev = define_events(P);  end

W.E = complex(zeros(P.Nz, P.Npulses, 'single'));
W.z = P.z;
W.t = P.t_slow;

fprintf('simulate_waterfall: %d pulses x %d samples\n', P.Npulses, P.Nz);
tic;
step = round(P.Npulses / 10);

for m = 1:P.Npulses
    h = apply_event(F, ev, m);
    T = simulate_trace(P, F, h);
    W.E(:, m) = single(T.E);

    if mod(m, step) == 0
        fprintf('  %3.0f%%  (%.1f s)\n', 100*m/P.Npulses, toc);
    end
end
fprintf('simulate_waterfall: done in %.1f s\n', toc);
end