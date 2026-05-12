clc;
clear;
close all;

eeg_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S06_E01/OpenBCISession_S06_E01/OpenBCI-RAW-2026-04-28_15-45-12.txt';
label_file = '/Users/melisakizilelma/Desktop/Experiment_GUI/DATAS/OpenBCISession_S06_E01/ExperimentReport_2026-04-28_16-01-52.txt';
fs = 125;

rng(1);

maxTrialSec = 3.0;
trainRatio = 0.75;

windowLength = 250;   % 2 sec
stepSize = 125;       % 1 sec shift

removeChannels = []; 

% preprocessing
useNotch = true;
notchLow = 48;
notchHigh = 52;
useBandpass = true;
bpLow = 3;
bpHigh = 40;

valRatio = 0.15;

% transformer
dModel = 32;
numHeads = 2;
dropProb = 0.3;

opts = detectImportOptions(eeg_file, ...
    'FileType','text', ...
    'Delimiter', ',', ...
    'CommentStyle','%');

EEGtable = readtable(eeg_file, opts);
eegData = EEGtable{:, 2:17};   % 16 EEG channels

label_lines = readlines(label_file);

start_times = [];
end_times = [];
labels_num = [];

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
            labels_num(end+1,1) = freq_value;

        elseif contains(line_text, "Ended")
            end_times(end+1,1) = time_value;
        end
    end
end

% label to samples
start_samples = round(start_times * fs) + 1;
end_samples   = round(end_times * fs);

num_trials = min([numel(start_samples), numel(end_samples), numel(labels_num)]);
start_samples = start_samples(1:num_trials);
end_samples   = end_samples(1:num_trials);
labels_num    = labels_num(1:num_trials);

trial_lengths = end_samples - start_samples + 1;
trial_length = min([min(trial_lengths), round(maxTrialSec * fs)]);

% matrix
X = zeros(16, trial_length, num_trials);
Y = zeros(num_trials,1);

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
    Y(valid_count,1) = labels_num(k);
end

X = X(:,:,1:valid_count);
Y = Y(1:valid_count);

if ~isempty(removeChannels)
    X(removeChannels,:,:) = [];
end

[num_channels, num_time, num_trials] = size(X);
Y = categorical(Y);


%preprocessing
X_pre = X;

if useBandpass
    bpFilt = designfilt('bandpassiir', ...
        'FilterOrder', 4, ...
        'HalfPowerFrequency1', bpLow, ...
        'HalfPowerFrequency2', bpHigh, ...
        'SampleRate', fs);
end

if useNotch
    notchFilt = designfilt('bandstopiir', ...
        'FilterOrder', 4, ...
        'HalfPowerFrequency1', notchLow, ...
        'HalfPowerFrequency2', notchHigh, ...
        'SampleRate', fs);
end

for trial = 1:num_trials

    data = squeeze(X(:,:,trial))';   % time x channels

    if useBandpass
        data = filtfilt(bpFilt, data);
    end

    if useNotch
        data = filtfilt(notchFilt, data);
    end

    % channel-wise centering
    data = data - mean(data,1);

    X_pre(:,:,trial) = data';        % channels x time
end

dataCell = cell(num_trials,1);
for trial = 1:num_trials
    dataCell{trial} = X_pre(:,:,trial);   % channels x time
end

labels = Y;
classNames = categories(labels);

% train/test

idxTrain = [];
idxVal   = [];
idxTest  = [];

for i = 1:numel(classNames)
    classIdx = find(labels == classNames{i});
    classIdx = classIdx(randperm(numel(classIdx)));

    n = numel(classIdx);

    numTrainClass = floor(trainRatio * n);
    numValClass   = floor(valRatio * n);
    numTestClass  = n - numTrainClass - numValClass;

    if n >= 3
        if numTrainClass < 1, numTrainClass = 1; end
        if numValClass < 1, numValClass = 1; end
        numTestClass = n - numTrainClass - numValClass;

        if numTestClass < 1
            numTestClass = 1;
            if numTrainClass > numValClass
                numTrainClass = numTrainClass - 1;
            else
                numValClass = numValClass - 1;
            end
        end
    end

    idxTrain = [idxTrain; classIdx(1:numTrainClass)];
    idxVal   = [idxVal;   classIdx(numTrainClass+1:numTrainClass+numValClass)];
    idxTest  = [idxTest;  classIdx(numTrainClass+numValClass+1:end)];
end

idxTrain = idxTrain(randperm(numel(idxTrain)));
idxVal   = idxVal(randperm(numel(idxVal)));
idxTest  = idxTest(randperm(numel(idxTest)));

XTrainTrials = dataCell(idxTrain);
TTrainTrials = labels(idxTrain);

XValTrials   = dataCell(idxVal);
TValTrials   = labels(idxVal);

XTestTrials  = dataCell(idxTest);
TTestTrials  = labels(idxTest);

% windowing
if num_time < windowLength
    windowLength = num_time;
    stepSize = num_time;
end

% train
XTrainWin = {};
TTrainWin = categorical();
trainTrialID = [];

count = 0;
for i = 1:numel(XTrainTrials)

    seq = XTrainTrials{i};   % channels x time
    numSamples = size(seq,2);

    if numSamples < windowLength
        continue
    end

    for startPos = 1:stepSize:(numSamples - windowLength + 1)
        endPos = startPos + windowLength - 1;
        segment = seq(:, startPos:endPos);

        count = count + 1;
        XTrainWin{count,1} = segment;
        TTrainWin(count,1) = TTrainTrials(i);
        trainTrialID(count,1) = i;
    end
end
% validation
XValWin = {};
TValWin = categorical();
valTrialID = [];

count = 0;
for i = 1:numel(XValTrials)

    seq = XValTrials{i};   % channels x time
    numSamples = size(seq,2);

    if numSamples < windowLength
        continue
    end

    for startPos = 1:stepSize:(numSamples - windowLength + 1)
        endPos = startPos + windowLength - 1;
        segment = seq(:, startPos:endPos);

        count = count + 1;
        XValWin{count,1} = segment;
        TValWin(count,1) = TValTrials(i);
        valTrialID(count,1) = i;
    end
end
% test
XTestWin = {};
TTestWin = categorical();
testTrialID = [];

count = 0;
for i = 1:numel(XTestTrials)

    seq = XTestTrials{i};   % channels x time
    numSamples = size(seq,2);

    if numSamples < windowLength
        continue
    end

    for startPos = 1:stepSize:(numSamples - windowLength + 1)
        endPos = startPos + windowLength - 1;
        segment = seq(:, startPos:endPos);

        count = count + 1;
        XTestWin{count,1} = segment;
        TTestWin(count,1) = TTestTrials(i);
        testTrialID(count,1) = i;
    end
end

 %fft features
% N = windowLength;
% 
% XTrain = cell(numel(XTrainWin),1);
% for i = 1:numel(XTrainWin)
%     seg = XTrainWin{i};                % channels x time
% 
%     spec = fft(seg, [], 2) / N;
%     spec = spec(:, 1:floor(N/2)+1);    % full one-sided spectrum
%     spec = spec(:, 2:end);             % remove only 0 Hz
% 
%     feat = [real(spec); imag(spec)];   % (2*channels) x freqBins
%     XTrain{i} = feat;
% end
% 
% XVal = cell(numel(XValWin),1);
% for i = 1:numel(XValWin)
%     seg = XValWin{i};                  % channels x time
% 
%     spec = fft(seg, [], 2) / N;
%     spec = spec(:, 1:floor(N/2)+1);    % full one-sided spectrum
%     spec = spec(:, 2:end);             % remove only 0 Hz
% 
%     feat = [real(spec); imag(spec)];   % (2*channels) x freqBins
%     XVal{i} = feat;
% end
% 
% XTest = cell(numel(XTestWin),1);
% for i = 1:numel(XTestWin)
%     seg = XTestWin{i};                 % channels x time
% 
%     spec = fft(seg, [], 2) / N;
%     spec = spec(:, 1:floor(N/2)+1);    % full one-sided spectrum
%     spec = spec(:, 2:end);             % remove only 0 Hz
% 
%     feat = [real(spec); imag(spec)];   % (2*channels) x freqBins
%     XTest{i} = feat;
% end

%only magnitude 
N = windowLength;
freqAxis = (0:floor(N/2)) * fs / N;

fminFeat = 6;
fmaxFeat = 30;
keepIdx = (freqAxis >= fminFeat) & (freqAxis <= fmaxFeat);

XTrain = cell(numel(XTrainWin),1);
for i = 1:numel(XTrainWin)
    seg = XTrainWin{i};                % channels x time

    spec = fft(seg, [], 2) / N;
    spec = spec(:, 1:floor(N/2)+1);    
    magSpec = abs(spec);               
    magSpec = magSpec(:, keepIdx);     

    XTrain{i} = magSpec;               % channels x keptFreqBins
end

XVal = cell(numel(XValWin),1);
for i = 1:numel(XValWin)
    seg = XValWin{i};

    spec = fft(seg, [], 2) / N;
    spec = spec(:, 1:floor(N/2)+1);
    magSpec = abs(spec);
    magSpec = magSpec(:, keepIdx);

    XVal{i} = magSpec;
end

XTest = cell(numel(XTestWin),1);
for i = 1:numel(XTestWin)
    seg = XTestWin{i};

    spec = fft(seg, [], 2) / N;
    spec = spec(:, 1:floor(N/2)+1);
    magSpec = abs(spec);
    magSpec = magSpec(:, keepIdx);

    XTest{i} = magSpec;
end

TTrain = TTrainWin;
TVal   = TValWin;
TTest  = TTestWin;
allCats = categories(labels);

TTrain = categorical(string(TTrain), allCats);
TVal   = categorical(string(TVal),   allCats);
TTest  = categorical(string(TTest),  allCats);

%transformer
numInputFeatures = size(XTrain{1},1);
numClasses = numel(categories(TTrain));

layers = [
    sequenceInputLayer(numInputFeatures, Normalization="zscore")
    convolution1dLayer(1, dModel, Padding="same")
    selfAttentionLayer(numHeads, dModel)
    globalAveragePooling1dLayer
    dropoutLayer(dropProb)
    fullyConnectedLayer(numClasses)
    softmaxLayer
    classificationLayer
];

options = trainingOptions("adam", ...
    MaxEpochs=40, ...
    MiniBatchSize=8, ...
    InitialLearnRate=0.001, ...
    Shuffle="every-epoch", ...
    SequencePaddingDirection="left", ...
    GradientThreshold=1, ...
    ValidationData={XVal, TVal}, ...
    ValidationFrequency=10, ...
    ValidationPatience=8, ...
    Verbose=false, ...
    Plots="training-progress");

% train transformer
net = trainNetwork(XTrain, TTrain, layers, options);

% test
YPredWin = classify(net, XTest, SequencePaddingDirection="left");
windowAcc = mean(YPredWin == TTest) * 100;

fprintf('Window-level Transformer Accuracy: %.2f%%\n', windowAcc);

figure;
confusionchart(TTest, YPredWin);
title(sprintf('Window-Level Transformer Accuracy: %.2f%%', windowAcc));

% trial-level majority vote
uniqueTrials = unique(testTrialID);

YPredTrial = categorical();
TTrueTrial = categorical();

cats = categories(TTest);

for i = 1:numel(uniqueTrials)

    idx = (testTrialID == uniqueTrials(i));
    preds = YPredWin(idx);
    trueLabels = TTest(idx);

    counts = zeros(numel(cats),1);
    for c = 1:numel(cats)
        counts(c) = sum(preds == categorical(cats(c)));
    end

    [~, bestIdx] = max(counts);

    YPredTrial(i,1) = categorical(cats(bestIdx));
    TTrueTrial(i,1) = trueLabels(1);
end

trialAcc = mean(YPredTrial == TTrueTrial) * 100;
fprintf('Trial-level Transformer Accuracy: %.2f%%\n', trialAcc);

figure;
confusionchart(TTrueTrial, YPredTrial);
title(sprintf('Trial-Level Transformer Accuracy: %.2f%%', trialAcc));

YValPred = classify(net, XVal, SequencePaddingDirection="left");
valAcc = mean(YValPred == TVal) * 100;
fprintf('Validation Transformer Accuracy: %.2f%%\n', valAcc);