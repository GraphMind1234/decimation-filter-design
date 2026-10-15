% design_fir.m - CIC droop compensator design for TASK 2
% CIC: N = 4, R = 512, M = 1, input rate fs = 4.096 MHz (scoring-script units:
% output rate 2 kHz x OSR 2048).  FIR runs at fs/512 = 8 kHz, decimates by 4.
% Least-squares FIR: |H| = 1/|Hcic(f)| over 0..1000 Hz, 0 over 2..4 kHz.
% Requires firls (Signal Processing Toolbox / Octave signal package).
clear; clc;
N = 4; R = 512; fs_in = 4.096e6; fs1 = fs_in/R;       % 8 kHz
K = 27;                 % taps  (order 26, symmetric, type I)
fp = 1000; fst = 2000; wst = 10;
G = 3.5;                % overall output gain (input -11.1 dBFS -> -0.25 dBFS)
IW = 24; FRAC = 18;     % interstage word (FS = 2^23), coefficient Q18

hcic = @(f) abs(sin(pi*f*R/fs_in) ./ (R*sin(pi*f/fs_in))).^N;
fg = linspace(0, fp, 60);  fg(1) = 1e-9;
F = []; A = [];
for i = 1:numel(fg)-1
    F = [F fg(i) fg(i+1)];  A = [A 1/hcic(fg(i)) 1/hcic(fg(i+1))];
end
F = [F fst fs1/2];  A = [A 0 0];
W = [ones(1, numel(fg)-1) wst];
h = firls(K-1, F/(fs1/2), A, W);
h = h / sum(h);                                   % unity DC gain
g = G * 2^19 / 2^(IW-1);                          % 24b FS -> 20b FS, x G
hq = round(h * g * 2^FRAC);                       % integer coefficients
disp('Quantised coefficients (Q18):'); disp(hq);

% combined response check
f = linspace(1e-6, fs1/2, 4096);
Hf = abs(freqz(hq, 1, f, fs1)) .* hcic(f);  Hf = Hf / Hf(1);
pb = f <= 990; sb = f >= fst;
fprintf('Passband ripple 0..990 Hz : %.3f dB\n', 20*log10(max(Hf(pb))/min(Hf(pb))));
fprintf('Alias rejection >= %d Hz : %.1f dB\n', fst, -20*log10(max(Hf(sb))));
if exist('OCTAVE_VERSION','builtin') == 0
    figure; plot(f, 20*log10(Hf)); grid on; xlabel('Hz'); ylabel('dB');
    title('CIC(N=4,R=512) x FIR compensator, normalised');
end
