clc;
clear;
close all;

eeg_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S15_E01/OpenBCI-RAW-2026-05-04_13-50-48.txt';
label_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S15_E01/ExperimentReport_2026-05-04_14-07-24.txt';
fs = 125;

% read EEG
opts = detectImportOptions(eeg_file, ...
    'FileType','text', ...
    'Delimiter', ',', ...
    'CommentStyle','%');

EEGtable = readtable(eeg_file, opts);

eegData = EEGtable{:, 2:17};

% read label file
label_lines = readlines(label_file);

start_times = [];
end_times = [];
labels = [];

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
            start_times(end+1,1) = time_value;
            labels(end+1,1) = freq_value;

        elseif contains(line_text, "Ended")
            end_times(end+1,1) = time_value;
        end
    end
end

% label times to samples
start_samples = round(start_times * fs) + 1;
end_samples   = round(end_times * fs);

num_trials = min([numel(start_samples), numel(end_samples), numel(labels)]);

start_samples = start_samples(1:num_trials);
end_samples   = end_samples(1:num_trials);
labels        = labels(1:num_trials);

trial_lengths = end_samples - start_samples + 1;
max_trial_length = round(3 * fs);
trial_length = min([min(trial_lengths), max_trial_length]);

% trial matrix
X = zeros(16, trial_length, num_trials);
Y = zeros(num_trials, 1);

valid_count = 0;

for k = 1:num_trials

    s1 = start_samples(k);
    s2 = s1 + trial_length - 1;

    if s2 > size(eegData,1)
        continue
    end

    valid_count = valid_count + 1;

    trial_data = eegData(s1:s2, :);   % time x channels

    X(:,:,valid_count) = trial_data'; % channels x time
    Y(valid_count,1) = labels(k);
end

X = X(:,:,1:valid_count);
Y = Y(1:valid_count);

% channel removal
% X(7,:,:) = [];
% X([3 5 7],:,:) = [];

[num_channels, num_time, num_trials] = size(X);

Y = categorical(Y);

% Preprocessing: 
X_pre = X;

bpFilt = designfilt('bandpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', 3, ...
    'HalfPowerFrequency2', 40, ...
    'SampleRate', fs);

notchFilt = designfilt('bandstopiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', 48, ...
    'HalfPowerFrequency2', 52, ...
    'SampleRate', fs);

for trial = 1:num_trials

    data = squeeze(X(:,:,trial))';   % time x channels

    % data = filtfilt(bpFilt, data);
    data = filtfilt(notchFilt, data);

    X_pre(:,:,trial) = data';        % channels x time
end

data = cell(num_trials,1);
for trial = 1:num_trials
    data{trial} = X_pre(:,:,trial);   % channels x time
end

labels = Y;

% train/test 
% train/val/test 
rng(4)

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

XVal   = data(idxVal);
TVal   = labels(idxVal);

XTest  = data(idxTest);
TTest  = labels(idxTest);
% Sliding window 
windowLength = 250;   % 2 sec
stepSize = 125;       % 1 sec shift

if num_time < windowLength
    windowLength = num_time;
    stepSize = num_time;
end

[XTrainWin, TTrainWin] = makeWindows(XTrain, TTrain, windowLength, stepSize);
[XValWin,   TValWin]   = makeWindows(XVal,   TVal,   windowLength, stepSize);
[XTestWin,  TTestWin]  = makeWindows(XTest,  TTest,  windowLength, stepSize);

XTrain = XTrainWin;
TTrain = TTrainWin;

XVal   = XValWin;
TVal   = TValWin;

XTest  = XTestWin;
TTest  = TTestWin;
% lstm
numFeatures = size(XTrain{1},1);
numClasses  = numel(categories(TTrain));

layers = [
    sequenceInputLayer(numFeatures, Normalization="zscore")
    bilstmLayer(32, OutputMode="last")
    dropoutLayer(0.5)
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer
];

options = trainingOptions("adam", ...
    MaxEpochs=50, ...
    MiniBatchSize=8, ...
    InitialLearnRate=0.001, ...
    Shuffle="every-epoch", ...
    SequencePaddingDirection="left", ...
    ValidationData={XVal, TVal}, ...
    ValidationFrequency=10, ...
    ValidationPatience=8, ...
    Verbose=false, ...
    Plots="training-progress");

% train
net = trainNetwork(XTrain, TTrain, layers, options);

% test
YPred = classify(net, XTest, SequencePaddingDirection="left");
accuracy = mean(YPred == TTest) * 100;

fprintf('Test Accuracy: %.2f%%\n', accuracy);

figure;
confusionchart(TTest, YPred);
title(sprintf('LSTM Confusion Matrix - Accuracy: %.2f%%', accuracy));

% Helper function
function [XWin, TWin] = makeWindows(XCell, TCell, windowLength, stepSize)

XWin = {};
TWin = TCell([]);

count = 0;

for i = 1:numel(XCell)

    seq = XCell{i};               % channels x time
    numSamples = size(seq,2);

    if numSamples < windowLength
        continue
    end

    for startPos = 1:stepSize:(numSamples - windowLength + 1)

        endPos = startPos + windowLength - 1;
        segment = seq(:, startPos:endPos);

        count = count + 1;
        XWin{count,1} = segment;
        TWin(count,1) = TCell(i);
    end
end
end

YPredTrain = classify(net, XTrain, SequencePaddingDirection="left");
trainAcc = mean(YPredTrain == TTrain) * 100;

YPredVal = classify(net, XVal, SequencePaddingDirection="left");
valAcc = mean(YPredVal == TVal) * 100;

YPredTest = classify(net, XTest, SequencePaddingDirection="left");
testAcc = mean(YPredTest == TTest) * 100;

disp('Train accuracy (%):')
disp(trainAcc)

disp('Validation accuracy (%):')
disp(valAcc)

disp('Test accuracy (%):')
disp(testAcc)