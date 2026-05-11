clc;
clear;
close all;

eeg_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S15_E01/OpenBCI-RAW-2026-05-04_13-50-48.txt';
label_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S15_E01/ExperimentReport_2026-05-04_14-07-24.txt';
fs = 125;

% matrix
opts = detectImportOptions(eeg_file, ...
    'FileType','text', ...
    'Delimiter', ',', ...
    'CommentStyle','%');

EEGtable = readtable(eeg_file, opts);
eegData = EEGtable{:, 2:17};  

%  label file
label_lines = readlines(label_file);

start_times = [];
end_times = [];
trial_labels = [];

for i = 1:numel(label_lines)

    line_text = strtrim(label_lines(i));

    if contains(line_text, "Freq") && contains(line_text, "Hz")

        time_text = extractBetween(line_text, "[", "s]");
        if isempty(time_text)
            continue
        end

        time_value = str2double(time_text);

        freq_text = extractBetween(line_text, "Freq", "Hz");
        freq_value = str2double(strtrim(freq_text));

        if contains(line_text, "Started")
            start_times(end+1) = time_value; 
            trial_labels(end+1) = freq_value; 
        elseif contains(line_text, "Ended")
            end_times(end+1) = time_value;
        end
    end
end

% times to samples
start_samples = round(start_times * fs) + 1;
end_samples   = round(end_times * fs);

num_trials = min([numel(start_samples), numel(end_samples), numel(trial_labels)]);

start_samples = start_samples(1:num_trials);
end_samples   = end_samples(1:num_trials);
trial_labels  = trial_labels(1:num_trials);

trial_lengths = end_samples - start_samples + 1;
trial_length = min(trial_lengths);

X = zeros(16, trial_length, num_trials);
Y = zeros(num_trials, 1);

valid_count = 0;

for k = 1:num_trials

    s1 = start_samples(k);
    s2 = s1 + trial_length - 1;

    if s1 < 1 || s2 > size(eegData, 1)
        continue
    end

    trial_data = eegData(s1:s2, :);   % time x channels

    valid_count = valid_count + 1;
    X(:,:,valid_count) = trial_data'; % channels x time
    Y(valid_count) = trial_labels(k);
end

X = X(:,:,1:valid_count);
Y = Y(1:valid_count);

% channel removal
% X(3,:,:) = [];
% X([3 5 7],:,:) = [];

[num_channels, num_time, num_trials] = size(X);
Y = categorical(Y);

% preprocessing

X_pre = X;

bpFilt = designfilt('bandpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', 3, ...
    'HalfPowerFrequency2', 40, ...
    'SampleRate', fs);
% 
% lpFilt = designfilt('lowpassiir', ...
%     'FilterOrder', 4, ...
%     'HalfPowerFrequency', 40, ...
%     'SampleRate', fs);

notchFilt = designfilt('bandstopiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', 48, ...
    'HalfPowerFrequency2', 52, ...
    'SampleRate', fs);

for trial = 1:num_trials
    data = squeeze(X(:,:,trial))';   % time x channels

    %data = filtfilt(lpFilt, data);
    data = filtfilt(bpFilt, data);
    data = filtfilt(notchFilt, data);

    X_pre(:,:,trial) = data';        % channels x time
end

X = X_pre;

data = cell(num_trials,1);
for trial = 1:num_trials
    data{trial} = X(:,:,trial);   % channels x time
end

labels = Y;

% train/test
rng(1)

classNames = categories(labels);

idxTrain = [];
idxVal   = [];
idxTest  = [];

for i = 1:numel(classNames)

    classIdx = find(labels == classNames{i});
    classIdx = classIdx(randperm(numel(classIdx)));

    n = numel(classIdx);

    nTrain = floor(0.70 * n);
    nVal   = floor(0.15 * n);
    nTest  = n - nTrain - nVal;

   
    if n >= 3
        if nTrain < 1, nTrain = 1; end
        if nVal < 1, nVal = 1; end
        nTest = n - nTrain - nVal;
        if nTest < 1
            nTest = 1;
            if nTrain > nVal
                nTrain = nTrain - 1;
            else
                nVal = nVal - 1;
            end
        end
    end

    idxTrain = [idxTrain; classIdx(1:nTrain)]; 
    idxVal   = [idxVal;   classIdx(nTrain+1:nTrain+nVal)];
    idxTest  = [idxTest;  classIdx(nTrain+nVal+1:end)]; 
end

idxTrain = idxTrain(randperm(numel(idxTrain)));
idxVal   = idxVal(randperm(numel(idxVal)));
idxTest  = idxTest(randperm(numel(idxTest)));

XTrain = data(idxTrain);
TTrain = labels(idxTrain);

XVal = data(idxVal);
TVal = labels(idxVal);

XTest = data(idxTest);
TTest = labels(idxTest);

% sliding window

% windowLength = 250;   % 2 sec
% stepSize     = 125;   % 1 sec overlap
% 
% [XTrainWin, TTrainWin, trainTrialID] = makeWindows(XTrain, TTrain, windowLength, stepSize);
% [XValWin,   TValWin,   valTrialID]   = makeWindows(XVal,   TVal,   windowLength, stepSize);
% [XTestWin,  TTestWin,  testTrialID]  = makeWindows(XTest,  TTest,  windowLength, stepSize);

% no sliding window
XTrainWin = XTrain;
TTrainWin = TTrain;

XValWin = XVal;
TValWin = TVal;

XTestWin = XTest;
TTestWin = TTest;

% cnn

filterSize = 5;
numFilters = 32;
numClasses = numel(categories(TTrainWin));

layers = [
    sequenceInputLayer(num_channels, Normalization="zscore")

    convolution1dLayer(filterSize, numFilters, Padding="same")
    reluLayer
    layerNormalizationLayer
    dropoutLayer(0.3)

    convolution1dLayer(filterSize, 2*numFilters, Padding="same")
    reluLayer
    layerNormalizationLayer
    dropoutLayer(0.3)

    convolution1dLayer(filterSize, 2*numFilters, Padding="same")
    reluLayer
    layerNormalizationLayer

    globalAveragePooling1dLayer

    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer
];

options = trainingOptions('adam', ...
    'MaxEpochs', 40, ...
    'MiniBatchSize', 16, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {XValWin, TValWin}, ...
    'ValidationFrequency', 10, ...
    'ValidationPatience', 8, ...
    'Plots', 'training-progress', ...
    'Verbose', false);

%train

net = trainNetwork(XTrainWin, TTrainWin, layers, options);

% test

YPredWin = classify(net, XTestWin, SequencePaddingDirection="left");
windowAccuracy = mean(YPredWin == TTestWin) * 100;

disp('Window-level test accuracy (%):')
disp(windowAccuracy)

figure
confusionchart(TTestWin, YPredWin)
title('Window-Level CNN Confusion Matrix')


% trialPred = majorityVoteLabels(YPredWin, testTrialID);
% trialTrue = TTest;
% 
% trialAccuracy = mean(trialPred == trialTrue) * 100;
% 
% disp('Trial-level test accuracy (%):')
% disp(trialAccuracy)
% 
% figure
% confusionchart(trialTrue, trialPred)
% title('Trial-Level CNN Confusion Matrix')

function [XWin, TWin, trialID] = makeWindows(XCell, TCell, windowLength, stepSize)

    XWin = {};
    TWin = TCell([]);
    trialID = [];

    count = 0;

    for i = 1:numel(XCell)

        seq = XCell{i};                 % channels x time
        numSamples = size(seq, 2);

        if numSamples < windowLength
            continue
        end

        for startPos = 1:stepSize:(numSamples - windowLength + 1)

            endPos = startPos + windowLength - 1;
            segment = seq(:, startPos:endPos);

            count = count + 1;
            XWin{count,1} = segment;
            TWin(count,1) = TCell(i);
            trialID(count,1) = i; 
        end
    end
end

function trialPred = majorityVoteLabels(windowPred, trialID)

    uniqueTrials = unique(trialID);
    trialPred = categorical;

    for i = 1:numel(uniqueTrials)
        idx = (trialID == uniqueTrials(i));
        preds = windowPred(idx);

        cats = categories(preds);
        counts = zeros(numel(cats),1);

        for k = 1:numel(cats)
            counts(k) = sum(preds == cats{k});
        end

        [~, maxIdx] = max(counts);
        trialPred(i,1) = categorical(cats(maxIdx), cats);
    end
end
YPredTrain = classify(net, XTrainWin, SequencePaddingDirection="left");
trainAcc = mean(YPredTrain == TTrainWin) * 100;

disp('Train accuracy (%):')
disp(trainAcc)
