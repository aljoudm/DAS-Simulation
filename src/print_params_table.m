function print_params_table(p, fid)
% PRINT_PARAMS_TABLE  Print every field of the das_params struct p as
%                     name | value | unit | source.   (fid: default 1 = screen)
if nargin < 2, fid = 1; end

% name, unit, source ("datasheet" / "derived" / "assumed"), scale, display unit
T = {
 'lambda',        'm',     'datasheet'
 'alpha_dB_km',   'dB/km', 'datasheet'
 'L_fiber_sim',   'm',     'datasheet'
 'dz_res',        'm',     'datasheet'
 'dz_samp',       'm',     'datasheet'
 'P_DAS',         'W',     'datasheet'
 'n_g',           '-',     'assumed'
 'c',             'm/s',   'assumed'
 'xi',            '-',     'assumed'
 'scat_per_m',    '1/m',   'assumed'
 'alpha_s_dB_km', 'dB/km', 'assumed'
 'S_capture',     '-',     'assumed'
 'P0',            'W',     'assumed'
 'pulse_shape',   '-',     'assumed'
 'Npulses',       '-',     'assumed'
 'os',            '-',     'assumed'
 'SNR_dB',        'dB',    'assumed'
 'tau_ref',       's',     'assumed'
 'seed',          '-',     'assumed'
 'gauge',         'm',     'assumed'
 'tau_pulse',     's',     'derived'
 'f_s',           'Hz',    'derived'
 'T_rt',          's',     'derived'
 'f_rep_max',     'Hz',    'derived'
 'f_rep',         'Hz',    'assumed'      % chosen by the user (design choice)
 'f_vib_max',     'Hz',    'derived'
};
fprintf(fid, '\n%-15s %-14s %-6s %s\n', 'name', 'value', 'unit', 'source');
fprintf(fid, '%s\n', repmat('-', 1, 50));
for i = 1:size(T, 1)
    v = p.(T{i,1});
    if ischar(v), s = v; else, s = sprintf('%.6g', v); end
    fprintf(fid, '%-15s %-14s %-6s %s\n', T{i,1}, s, T{i,2}, T{i,3});
end
fprintf(fid, '\n');
end
