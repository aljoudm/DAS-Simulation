function F = fiber_model(P)
clc;
% FIBER_MODEL  Builds the static Rayleigh "fingerprint" of the fiber.
%
%   F = fiber_model(P)
%
%   The fiber is modeled as Nscat discrete scatterers at random positions.
%   Each scatterer has a random complex reflection coefficient r_k:
%       |r_k|  ~ Rayleigh distributed   (random size of glass defect)
%       phase  ~ Uniform[0, 2*pi)        (random microscopic position)
%
%   Each scatterer also gets the round-trip propagation phase 2*beta*z_k.
%   The scatterers are then summed onto the fine grid P.z_fine, giving the
%   complex impulse response h0(z) of the fiber. This fingerprint is
%   generated ONCE and stays fixed for all pulses (fiber at rest).
%
%   Output struct F:
%     F.Nscat   number of scatterers
%     F.z_k     scatterer positions [m]                (Nscat x 1)
%     F.r_k     complex reflection coefficients [sqrt(W)] (Nscat x 1)
%     F.h0      fiber impulse response on fine grid    (Nfine x 1)
%     F.att     round-trip FIELD attenuation exp(-alpha*z) (Nfine x 1)

%% 0) If called without input, load default parameters
if nargin < 1
    P = params();
end

%% 1) Reproducible randomness
rng(P.seed);

%% 2) Scatterer positions (uniform random along the simulated length)
L_sim   = P.Nfine * P.dz_fine;              % length covered by the grid
F.Nscat = round(L_sim * P.scat_per_m);
F.z_k   = sort(rand(F.Nscat, 1) * L_sim);

%% 3) Scatterer strength (power scaling)
% Backscattered power at the fiber start for a pulse covering dz_res:
%     P_bs = P0 * S * alpha_s * dz_res
% A pulse covers M = scat_per_m * dz_res scatterers whose fields add with
% random phases, so the average powers add: P_bs = M * sigma2
%     => sigma2 = P0 * S * alpha_s / scat_per_m   (independent of pulse!)
sigma2 = P.P0 * P.S * P.alpha_s / P.scat_per_m;   % mean |r_k|^2 [W]

% Circular complex Gaussian -> Rayleigh amplitude + uniform phase
F.r_k = sqrt(sigma2/2) * (randn(F.Nscat,1) + 1j*randn(F.Nscat,1));

%% 4) Add round-trip propagation phase and place on the fine grid
v   = F.r_k .* exp(1j * 2 * P.beta * F.z_k);    % contribution of each scatterer
idx = floor(F.z_k / P.dz_fine) + 1;             % fine-grid cell of each scatterer
idx = min(idx, P.Nfine);

% Several scatterers can fall in one cell: their fields are summed.
% (real/imag split keeps it compatible with all MATLAB versions)
F.h0 = accumarray(idx, real(v), [P.Nfine 1]) + ...
       1j * accumarray(idx, imag(v), [P.Nfine 1]);

%% 5) Attenuation (field, round trip): power e^{-2 alpha z} -> field e^{-alpha z}
F.att = exp(-P.alpha * P.z_fine(:));

%% 6) Expected backscatter level (for reference and later checks)
F.P_bs0     = P.P0 * P.S * P.alpha_s * P.dz_res;   % [W] at z = 0
F.P_bs0_dBm = 10*log10(F.P_bs0 / 1e-3);

fprintf('fiber_model: %d scatterers on %d fine cells (%.2f m each)\n', ...
        F.Nscat, P.Nfine, P.dz_fine);
fprintf('fiber_model: expected backscatter at start = %.1f nW (%.1f dBm)\n', ...
        F.P_bs0*1e9, F.P_bs0_dBm);
end