%% =============================================
% Fetal PCG Analysis for FPGA (Altera) - 2 Datasets
% Full signal plots + CSV + MIF generation
%% =============================================

clc; clear; close all;

%% Step 1: Define your local folder path
dataFolder = 'C:\featalpcg';  % <-- Update your folder path
outputFolder = fullfile(dataFolder,'Figures');
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

Fs = 333;  % Sampling frequency (Hz)

%% Step 2: Select 2 datasets manually (one NORMAL, one ABNORMAL)
normalFile = fullfile(dataFolder,'fetal_PCG_p01_GW_36.dat');  % Replace with your normal file
abnormalFile = fullfile(dataFolder,'fetal_PCG_p07_GW_38.dat'); % Replace with your abnormal file

selectedFiles = {normalFile, abnormalFile};
numFiles = length(selectedFiles);
conditionsSummary = strings(numFiles,1);

%% Step 3: Process each file
for k = 1:numFiles
    filename = selectedFiles{k};
    [~, baseName, ext] = fileparts(filename);
    fprintf('\nProcessing file: %s\n', [baseName, ext]);

    % Read signal
    fid = fopen(filename,'r');
    rawSignal = fread(fid,'uint8');
    fclose(fid);
    rawSignal = double(rawSignal) / max(rawSignal);
    time = (0:length(rawSignal)-1)' / Fs;

    % Denoising
    [b,a] = butter(4,[20 100]/(Fs/2),'bandpass');
    filteredSignal = filter(b,a,rawSignal);
    filteredSignal = medfilt1(filteredSignal,3);

    % Peak detection
    threshold = mean(filteredSignal) + 0.5*std(filteredSignal);
    [peaks, locs] = findpeaks(filteredSignal,'MinPeakHeight',threshold,'MinPeakDistance',0.3*Fs);

    % Heart rate estimation
    windowSec = 10; windowSamples = windowSec * Fs;
    HR_bpm = []; HR_time = [];
    for startIdx = 1:windowSamples:length(filteredSignal)-windowSamples
        windowLocs = locs(locs >= startIdx & locs < startIdx + windowSamples);
        beats = length(windowLocs);
        HR_bpm(end+1) = beats * (60 / windowSec);
        HR_time(end+1) = (startIdx + windowSamples/2)/Fs;
    end
    avgHR = mean(HR_bpm,'omitnan');
    if isempty(avgHR), avgHR = NaN; end

    % Condition classification
    if isnan(avgHR)
        condition = "NO DATA";
    elseif avgHR < 110 || avgHR > 160
        condition = "ABNORMAL";
    else
        condition = "NORMAL";
    end
    conditionsSummary(k) = condition;
    fprintf('Condition: %s | Avg HR: %.2f bpm\n', condition, avgHR);

    %% --- Plot full signal ---
    fig = figure('Visible','on','Name',[baseName, ext],'NumberTitle','off');

    subplot(3,1,1);
    plot(time, rawSignal,'c');
    title('Raw PCG Signal'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

    subplot(3,1,2);
    plot(time, filteredSignal,'b'); hold on;
    plot(locs/Fs, filteredSignal(locs),'ro','MarkerFaceColor','r');
    title(['Filtered + Peaks | ', condition]); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

    subplot(3,1,3);
    plot(HR_time, HR_bpm,'-m','LineWidth',1.5);
    title(['Heart Rate (BPM) | ', condition]); xlabel('Time (s)'); ylabel('BPM'); grid on;

    drawnow;
    pause(0.5);

    % Save figure
    saveas(fig, fullfile(outputFolder,[baseName,'.png']));

    %% --- Save CSV outputs ---
    writematrix([time, filteredSignal], fullfile(dataFolder,[baseName,'_PCG_Input_Vector.csv']));
    writematrix([locs, peaks], fullfile(dataFolder,[baseName,'_PCG_Peaks_Vector.csv']));
    writematrix([HR_time', HR_bpm'], fullfile(dataFolder,[baseName,'_HeartRate_Vector.csv']));

    %% --- Generate MIF for FPGA ---
    signalNorm = (filteredSignal - min(filteredSignal)) / (max(filteredSignal)-min(filteredSignal));
    signal8bit = round(signalNorm*255);
    depth = length(signal8bit);
    width = 8;
    mifFile = fullfile(dataFolder,[baseName,'_signal.mif']);
    fid = fopen(mifFile,'w');
    fprintf(fid,'DEPTH = %d;\n',depth);
    fprintf(fid,'WIDTH = %d;\n',width);
    fprintf(fid,'ADDRESS_RADIX = UNS;\n');
    fprintf(fid,'DATA_RADIX = UNS;\n');
    fprintf(fid,'CONTENT BEGIN\n');
    for i = 1:depth
        fprintf(fid,'    %d : %d;\n',i-1,signal8bit(i));
    end
    fprintf(fid,'END;\n'); fclose(fid);
    fprintf('✅ MIF file created: %s\n', mifFile);
end

%% Step 4: Display summary
fprintf('\n================ SUMMARY ================\n');
for k = 1:numFiles
    fprintf('File: %-20s | Condition: %s\n', selectedFiles{k}, conditionsSummary(k));
end

disp('🚀 Processing completed. Figures, CSVs, and MIF files are ready.');
