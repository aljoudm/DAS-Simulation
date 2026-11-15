function out = print_expected_signal(p, z_km)
% PRINT_EXPECTED_SIGNAL  Expected backscatter power and SNR vs distance
%   (analytic, from das_params):  P_bs(z) = P0*R(tau)*10^(-2*alpha_dB_km*z/1e4)
%   SNR(z) = P_bs(z) / P_noise.
if nargin < 1, p = das_params(); end
if nargin < 2, z_km = [0 10 20]; end
z   = z_km(:)' * 1e3;
Pbs = p.P0 * p.R_bs_tau * 10.^(-2*p.alpha_dB_km*z/1e4);
snr = 10*log10(Pbs / p.P_noise);
fprintf('\nExpected signal (tau = %.1f ns, P0 = %.0f mW, R_bs(tau) = %.1f dB, noise = %.3f nW)\n', ...
        p.tau_pulse*1e9, p.P0*1e3, 10*log10(p.R_bs_tau), p.P_noise*1e9);
fprintf('  z [km]   P_bs [nW]   P_bs [dBm]   SNR [dB]\n');
for i = 1:numel(z)
    fprintf('  %5.1f   %9.2f   %9.1f   %8.1f\n', z_km(i), Pbs(i)*1e9, 10*log10(Pbs(i)/1e-3), snr(i));
end
fprintf('\n');
if nargout, out = struct('z_km', z_km, 'Pbs', Pbs, 'snr_dB', snr); end
end
