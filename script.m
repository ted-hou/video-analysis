
%% Read tetrode recording (SLOW!!!)
fname_tr = 'tr_sorted_daisy10_20211020.mat';
load(fname_tr)


%%
smoothingWindow_jointVel = 10;
smoothingWindow_spikeCount = 10;

%% Read video tracking data, csv to table
fname_vtd = 'daisy10_20211020_1croppedDLC_resnet101_daisy910Dec8shuffle1_800000.csv';
opts = detectImportOptions(fname_vtd, 'NumHeaderLines', 3);
opts.VariableNamesLine = 2;
vtd = readtable(fname_vtd, opts);

% Set colnames
vtd.Properties.VariableNames{1} = 'FrameNumber';
w = length(vtd.Properties.VariableNames);
for i = 2:w
    splitName = strsplit(vtd.Properties.VariableNames{i}, '_');
    if length(splitName) == 1
        vtd.Properties.VariableNames{i} = [splitName{1}, '_X'];
        pos = table2array(smoothdata(vtd(:, i:i+1), 'gaussian', smoothingWindow_jointVel));
        vel = [0, 0; diff(pos, 1)];
        spd = sqrt(sum(vel.^2, 2));
        vtd = addvars(vtd, vel(:, 1), vel(:, 2), spd, 'NewVariableNames', {[splitName{1}, '_VelX'], [splitName{1}, '_VelY'], [splitName{1}, '_Speed']});
    elseif splitName{2} == '1'
        vtd.Properties.VariableNames{i} = [splitName{1}, '_Y'];
    elseif splitName{2} == '2'
        vtd.Properties.VariableNames{i} = [splitName{1}, '_Likelihood'];
    end
end
clear i opts splitName w pos vel spd


%% Get time offset between video frame 0 and recording start time
fname_ac = 'daisy10_20211020.mat';
load(fname_ac), ac = obj; clear obj

% CameraConnection uses DATENUM to store local time (Boston) rather than UTC, so we need to specify timezone when converting back to DATETIME.
sparseTimestamps = datetime([ac.Cameras.Camera.EventLog.Timestamp], 'ConvertFrom', 'datenum', 'TimeZone', 'America/New_York', 'Format', 'yyyy-MM-dd HH:mm:SSS');
sparseFrameNumbers = [ac.Cameras.Camera.EventLog.FrameNumber];

% Interpolate frame timestamps b/c CameraConnection only stores timestamps
% for every 10th frame
vtd.FrameTimestamp = interp1(sparseFrameNumbers, sparseTimestamps, vtd.FrameNumber, 'linear');

% Store timestamps as seconds after Ephys start
vtd.EphysTimestamp = seconds(vtd.FrameTimestamp - tr.StartTime);

% Truncate negative timestamps
vtd = vtd(vtd.EphysTimestamp > 0, :);

clear sparseFrameNumbers sparseTimestamps

%% Process unit list
fname_peth = 'PETH_daisy10_20211020.mat';
load(fname_peth)
units = cell2table(batchPlotList, 'VariableNames', {'AnimalName', 'Date', 'Electrode', 'Channel', 'Unit'});
clear batchPlotList PETH

%% Calculate spike counts across whole session
units.SpikeCounts = zeros(height(units), height(vtd));
for iUnit = 1:height(units)
    sc = countspikes(tr, units.Channel(iUnit), units.Unit(iUnit), [0; vtd.EphysTimestamp]);
    units.SpikeCounts(iUnit, :) = sc;
    vtd = addvars(vtd, sc', smoothdata(sc', 'gaussian', smoothingWindow_spikeCount), 'NewVariableNames', {sprintf('SpikeCount_E%iU%i', units.Electrode(iUnit), units.Unit(iUnit)), sprintf('SmoothSpikeCount_E%iU%i', units.Electrode(iUnit), units.Unit(iUnit))});
end
clear iUnit sc

%% GLM
modelspec = cell(height(units), 1);
models = cell(height(units), 1);
for i = 1:height(units)
    e = units.Electrode(i);
    u = units.Unit(i);
    modelspec{i} = sprintf('SmoothSpikeCount_E%iU%i ~ Jaw_Speed + Nose_Speed + Spine_Speed + Tail_Speed + ShoulderR_Speed + ElbowR_Speed + HandR_Speed + HipR_Speed + AnkleR_Speed + FootR_Speed + HandL_Speed', e, u);
%     modelspec{i} = sprintf('SpikeCount_E%iU%i ~ Jaw_VelX + Nose_VelX + Spine_VelX + Tail_VelX + ShoulderR_VelX + ElbowR_VelX + HandR_VelX + HipR_VelX + AnkleR_VelX + FootR_VelX + HandL_VelX + Jaw_VelY + Nose_VelY + Spine_VelY + Tail_VelY + ShoulderR_VelY + ElbowR_VelY + HandR_VelY + HipR_VelY + AnkleR_VelY + FootR_VelY + HandL_VelY', e, u);
%     modelspec{i} = sprintf('SmoothSpikeCount_E%iU%i ~ Jaw_VelX + Nose_VelX + Spine_VelX + Tail_VelX + ShoulderR_VelX + ElbowR_VelX + HandR_VelX + HipR_VelX + AnkleR_VelX + FootR_VelX + HandL_VelX + Jaw_VelY + Nose_VelY + Spine_VelY + Tail_VelY + ShoulderR_VelY + ElbowR_VelY + HandR_VelY + HipR_VelY + AnkleR_VelY + FootR_VelY + HandL_VelY', e, u);
    mdl = fitglm(vtd, modelspec{i}, 'Distribution', 'poisson');
    models{i} = mdl;
%     
%     figure(i)
%     y = table2array(vtd(:, sprintf('SmoothSpikeCount_E%iU%i', e, u)));
%     subplot(1, 3, 1)
%     plot(vtd.HandR_Speed, y, '.')
%     xlabel('HandR Speed')
%     ylabel(sprintf('SmoothSpikeCount_E%iU%i', e, u))
%     subplot(1, 3, 2)
%     plot(vtd.HandR_VelX, y, '.')
%     xlabel('HandR Vel X')
%     subplot(1, 3, 3)
%     plot(vtd.HandR_VelY, y, '.')
%     xlabel('HandR Vel Y')
end

clear i e u mdl


%% Plot unit PETHs and significant predictors
for i = 1:height(units)
    [hFigure, ~, ~, hTitle] = tr.PlotUnitSimple_TwoEvents(units.Channel(i), units.Unit(i), 'LeaveSpaceForAnnotation', true, 'PlotType', 'PETH');
    
    coeff = models{i}.Coefficients;
    coeff = coeff(coeff.pValue < 0.05, :);
    coeff = sortrows(coeff, 'pValue');
    
    coeff_str = evalc('disp(coeff)');
    coeff_str = strrep(coeff_str, '<strong>', '\bf');
    coeff_str = strrep(coeff_str, '</strong>', '\rm');
    coeff_str = strrep(coeff_str, '_', '\_');

    dev = devianceTest(models{i});
    try
        dev_str = sprintf('\\bfChi^2-statistic vs. constant model: %.2f, p-value = %.2f\\rm\n\n', dev.chi2Stat(2), dev.pValue(2));
    catch
        dev_str = sprintf('\\bfF-statistic vs. constant model: %.2f, p-value = %.2f\\rm\n\n', dev.FStat(2), dev.pValue(2));
    end

    annotation(hFigure, 'Textbox', 'String', [dev_str, coeff_str], 'Interpreter', 'Tex', 'FontName', get(0,'FixedWidthFontName'), 'Units', 'Normalized', 'Position',[0 0 0.66 0.33], 'HorizontalAlignment', 'center', 'LineStyle', 'none');
    ax = axes(hFigure, 'OuterPosition', [0.66, 0.1, 0.33, 0.23]);
    hold(ax, 'on')
    t = (0:height(models{i}.Fitted)-1) * 1/30;
    plot(ax, t, table2array(models{i}.Variables(:, models{i}.Formula.ResponseName)) * 30, 'DisplayName', 'Data')
    plot(ax, t, table2array(models{i}.Fitted(:, 'Response')) * 30, 'DisplayName', 'Fitted')
    xlim(ax, [0, 60])
    hold(ax, 'off')
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'Spike Rate (sp/s)')
    legend(ax)
    title(ax, sprintf('R^2 = %f', models{i}.Rsquared.Ordinary))
    
    print(hFigure, hTitle.String, '-dpng')
end

clear i coeff coeff_str dev dev_str t

function sc = countspikes(tr, channel, unit, edges)
    spiketimes = tr.Spikes(channel).Timestamps(tr.Spikes(channel).Cluster.Classes == unit);
    sc = histcounts(spiketimes, edges);
end
