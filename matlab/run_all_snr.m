% Runs all 6 SNR scripts. Put the 6 .txt files from Vivado in this folder first.
clc;
snr_cic2048_10;   r(1)=sndr;  snr_cic2048_500; r(2)=sndr;  snr_cic2048_990; r(3)=sndr;
snr_fircomp_10;   r(4)=sndr;  snr_fircomp_500; r(5)=sndr;  snr_fircomp_990; r(6)=sndr;
fprintf('\n============== SNDR SUMMARY ==============\n');
fprintf('Tone      Task1 (CIC)     Task2 (CIC+FIR)\n');
t = [10 500 990];
for q = 1:3, fprintf('%4d Hz   %8.2f dB      %8.2f dB\n', t(q), r(q), r(q+3)); end
