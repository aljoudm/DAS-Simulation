function p = pulse(P)
% PULSE  Probe pulse shape on the fine distance grid.
%
%   p = pulse(P)   returns a column vector (field amplitude, peak = 1).
%
%   Why a distance grid and not a time grid?
%   At any instant the detector receives light from all scatterers inside
%   a fiber section of length  vg*tau/2 = dz_res  (round trip halves it).
%   So the pulse "seen" along the fiber is dz_res long, i.e. Np fine cells.
%
%   Power is already included in the scatterers (P0 inside r_k), so the
%   pulse here is only a SHAPE with peak amplitude 1.

if nargin < 1
    P = params();
end

Np = round(P.dz_res / P.dz_fine);    % pulse length in fine cells

switch lower(P.pulse_shape)
    case 'rect'
        p = ones(Np, 1);

    case 'gauss'
        % tau is the FWHM of the power, so Np cells = FWHM of |p|^2
        sig_pow = Np / (2*sqrt(2*log(2)));   % std of power profile
        sig_fld = sig_pow * sqrt(2);         % field is wider by sqrt(2)
        n = (-ceil(3*sig_fld):ceil(3*sig_fld))';
        p = exp(-n.^2 / (2*sig_fld^2));

    otherwise
        error('pulse:shape', 'Unknown pulse_shape "%s". Use rect or gauss.', ...
              P.pulse_shape);
end
end