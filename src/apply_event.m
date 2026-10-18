function [h, phi] = apply_event(F, ev, m)
% APPLY_EVENT  Fiber impulse response at pulse number m, with vibrations.
%
%   [h, phi] = apply_event(F, ev, m)
%
%   Takes the static fingerprint F.h0 and multiplies every fine cell by
%   exp(j*phi(z)), where phi(z) is the sum over all events of
%   ramp_i(z) * phi_t_i(m).  Scatterer amplitudes are NOT changed:
%   a vibration only changes the optical path, i.e. the phase.
%
%   h    modified impulse response, pass it to simulate_trace(P, F, h)
%   phi  total extra phase along the fiber at this pulse [rad]

phi = zeros(size(F.h0));
for i = 1:numel(ev)
    phi = phi + ev(i).ramp * ev(i).phi_t(m);
end
h = F.h0 .* exp(1j * phi);
end