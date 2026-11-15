function print_params_table(p, fid)
% PRINT_PARAMS_TABLE  Print every value of the das_params struct p as
%                     name | value | unit | FINAL source.   (fid: default 1 = screen)
if nargin < 2, fid = 1; end

T = {   % name, unit
 'tau_pulse_febus','s';  'dz_res_febus','m';  'f_s_febus','Hz'
 'f_rep_febus','Hz';     'P0_febus','W';      'linewidth_febus','Hz'
 'lambda','m';  'L_fiber_sim','m';  'alpha_dB_km','dB/km';  'dz_samp','m';  'dz_res','m'
 'P_DAS','W';  'n_g','-';  'R_bs_dB','dB';  'P0','W';  'linewidth','Hz';  'detection','-'
 'P_noise_ref','W';  'B_ref','Hz';  'T_rec_target','s'
 'xi','-';  'scat_per_m','1/m';  'pulse_shape','-'
 'os','-';  'seed','-'
 'c','m/s';  'v_g','m/s';  'tau_pulse','s';  'f_s','Hz';  'T_rt','s'
 'f_rep_max','Hz';  'f_rep','Hz';  'f_vib_max','Hz';  'Npulses','-';  'T_rec','s'
 'B_rx','Hz';  'P_noise','W';  'alpha_lin','1/m'
 'S_capture','-';  'R_bs_tau','-';  'P_bs0','W';  'SNR0_dB','dB'
 'gauge','m';  'dz_adc','m';  'Nz','-';  'mem_GB','GB'
};
fprintf(fid, '\n%-16s %-12s %-7s %s\n', 'name', 'value', 'unit', 'source (final)');
fprintf(fid, '%s\n', repmat('-', 1, 78));
for i = 1:size(T, 1)
    v = p.(T{i,1});
    if ischar(v), s = v; else, s = sprintf('%.6g', v); end
    fprintf(fid, '%-16s %-12s %-7s %s\n', T{i,1}, s, T{i,2}, p.src.(T{i,1}));
end
fprintf(fid, '\n');
end
