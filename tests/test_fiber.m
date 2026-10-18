% TEST_FIBER  Physical sanity check of fiber_model.m
%   Run from the DAS_Sim folder by typing:  test_fiber

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));   % model functions

P = params;
F = fiber_model(P);

figure('Name','Fiber model check');

subplot(1,2,1);
histogram(abs(F.r_k), 100, 'Normalization','pdf');
title('|r_k| — should be Rayleigh'); xlabel('amplitude'); ylabel('pdf');

subplot(1,2,2);
histogram(angle(F.r_k), 50, 'Normalization','pdf');
title('phase — should be flat'); xlabel('rad'); ylabel('pdf');

if isreal(F.r_k)
    fprintf('\nFAIL: r_k is real -> no interference possible.\n');
else
    fprintf('\nOK: r_k is complex (amplitude + phase).\n');
end