classdef VideoAnalysis < handle
	properties
		ExpName
		TetrodeRecording
		VideoTrackingData
		Events
		Trials
	end

	properties (Transient)

	end

	%----------------------------------------------------
	%		Methods
	%----------------------------------------------------
	methods
		function obj = VideoAnalysis()
		end

		% Store digital event timestamps (first in every trial) as seconds since video start
		function ProcessEvents(obj, varargin)
			p = inputParser;
			addParameter(p, 'Reference', 'CueOn', @ischar);
			addParameter(p, 'Event', 'PressOn', @ischar);
			parse(p, varargin{:});
			referenceName 	= p.Results.Reference;
			eventName	 	= p.Results.Event;

			for iObj = 1:length(obj)
				% Get first press times
				reference = obj(iObj).TetrodeRecording.DigitalEvents.(referenceName);
				event = obj(iObj).TetrodeRecording.DigitalEvents.(eventName);
				edges = [reference(1:end - 1), max(event(end), reference(end))];
				[~, ~, bins] = histcounts(event, edges);
				event = event(bins ~= 0);
				bins = nonzeros(bins);
				[iReference, iEvent] = unique(bins, 'first');
				reference = reference(iReference);
				event = event(iEvent);

				reference = seconds(obj(iObj).TetrodeRecording.GetStartTime() + seconds(reference) - obj(iObj).VideoTrackingData.Time(1));
				event = seconds(obj(iObj).TetrodeRecording.GetStartTime() + seconds(event) - obj(iObj).VideoTrackingData.Time(1));

				obj(iObj).Events.Reference = reference;
				obj(iObj).Events.ReferenceName = referenceName;
				obj(iObj).Events.Event = event;
				obj(iObj).Events.EventName = eventName;
			end
		end

		function ProcessData(obj, bodyPart, varargin)
			p = inputParser;
			addRequired(p, 'BodyPart', @(x) isnumeric(x) || ischar(x));
			addParameter(p, 'Window', [0 2], @isnumeric); % Extract data from [reference(iTrial) + window(1), event(iTrial) + window(2)]
			addParameter(p, 'SmoothingWindow', [1 1], @isnumeric); % [A, B] - Smooth using A samples before and B samples after. [] to disable smoothing.
			addParameter(p, 'SmoothingMethod', 'movmean', @ischar);
			addParameter(p, 'NumSigmas', 2, @isnumeric);
			addParameter(p, 'NumSigmasSpeed', 10, @isnumeric);
			parse(p, bodyPart, varargin{:});
			bodyPart		= p.Results.BodyPart;
			window			= p.Results.Window;
			smoothingWindow	= p.Results.SmoothingWindow;
			smoothingMethod	= p.Results.SmoothingMethod;
			numSigmas		= p.Results.NumSigmas;
			numSigmasSpeed	= p.Results.NumSigmasSpeed;

			if ischar(bodyPart)
				iBodyPart = find(strcmpi(bodyPart, {obj(1).VideoTrackingData.BodyPart.Name}));
			elseif isnumeric(bodyPart)
				iBodyPart = bodyPart;
			end

			for iObj = 1:length(obj)
				x = [obj(iObj).VideoTrackingData.BodyPart(iBodyPart).X];
				y = [obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Y];

				prob = [obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Likelihood];

				samplingFreq = (length(obj(iObj).VideoTrackingData.Time) - 1)/seconds(obj(iObj).VideoTrackingData.Time(end) - obj(iObj).VideoTrackingData.Time(1));
				t = seconds(obj(iObj).VideoTrackingData.Time - obj(iObj).VideoTrackingData.Time(1));

				% Interpolate missing positions
				xSmooth = x;
				ySmooth = y;
				isMissing = x <= 10 & y <= 10;
				xSmooth(isMissing) = nan;
				ySmooth(isMissing) = nan;
				xSmooth = fillmissing(xSmooth, 'linear');
				ySmooth = fillmissing(ySmooth, 'linear');

				if ~isempty(smoothingWindow) && ~strcmpi(smoothingMethod, 'none')
					xSmooth = smoothdata(xSmooth, smoothingMethod, smoothingWindow);
					ySmooth = smoothdata(ySmooth, smoothingMethod, smoothingWindow);
				end

				speed = [0; sqrt(diff(xSmooth).^2 + diff(ySmooth).^2)];
				speedSmooth = smoothdata(speed, smoothingMethod, smoothingWindow);
				% speedSmooth = speed;

				xSigma = median(abs(xSmooth - median(xSmooth)))/0.6745;
				ySigma = median(abs(ySmooth - median(ySmooth)))/0.6745;
				% speedSigma = median(abs(speedSmooth - median(speedSmooth)))/0.6745;
				speedSigma = std(speedSmooth);

				xThresholded = xSmooth;
				yThresholded = ySmooth;
				speedThresholded = speedSmooth;
				xThresholded(abs(xSmooth - median(xSmooth)) < numSigmas*xSigma) = median(xSmooth);
				yThresholded(abs(ySmooth - median(ySmooth)) < numSigmas*ySigma) = median(ySmooth);
				speedThresholded(abs(speedSmooth - mean(speedSmooth)) < numSigmasSpeed*speedSigma) = mean(speedSmooth);

				xNormalized = (xThresholded - median(xSmooth))/xSigma;
				yNormalized = (yThresholded - median(ySmooth))/ySigma;
				speedNormalized = (speedThresholded - mean(speedSmooth))/speedSigma;

				% Separate into windows
				reference = obj(iObj).Events.Reference;
				event = obj(iObj).Events.Event;
				for iTrial = 1:length(reference)
					obj(iObj).Trials(iTrial).Reference = reference(iTrial);
					obj(iObj).Trials(iTrial).Event = event(iTrial);

					inWindow = t >= reference(iTrial) + window(1) & t <= event(iTrial) + window(2);

					obj(iObj).Trials(iTrial).TimeRel = t(inWindow) - event(iTrial); % Time relative to movement
					obj(iObj).Trials(iTrial).TimeAbs = t(inWindow); % Time in video
					obj(iObj).Trials(iTrial).BodyPart(iBodyPart).Name = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Name;
					obj(iObj).Trials(iTrial).BodyPart(iBodyPart).X = struct('Raw', x(inWindow), 'Smooth', xSmooth(inWindow), 'Thresholded', xThresholded(inWindow), 'Normalized', xNormalized(inWindow));
					obj(iObj).Trials(iTrial).BodyPart(iBodyPart).Y = struct('Raw', y(inWindow), 'Smooth', ySmooth(inWindow), 'Thresholded', yThresholded(inWindow), 'Normalized', yNormalized(inWindow));
					obj(iObj).Trials(iTrial).BodyPart(iBodyPart).Speed = struct('Raw', speed(inWindow), 'Smooth', speedSmooth(inWindow), 'Thresholded', speedThresholded(inWindow), 'Normalized', speedNormalized(inWindow));
					obj(iObj).Trials(iTrial).BodyPart(iBodyPart).Prob = prob(inWindow);

					obj(iObj).Trials(iTrial).Length = obj(iObj).Trials(iTrial).TimeAbs(end) - obj(iObj).Trials(iTrial).TimeAbs(1);
				end

				% Store shit
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XSmooth = xSmooth;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YSmooth = ySmooth;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedSmooth = speedSmooth;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XThresholded = xThresholded;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YThresholded = yThresholded;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedThresholded = speedThresholded;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XNormalized = xNormalized;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YNormalized = yNormalized;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedNormalized = speedNormalized;
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XBaseline = median(xSmooth);
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YBaseline = median(ySmooth);
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedBaseline = mean(speedSmooth);
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.X = struct('Threshold', numSigmas*xSigma, 'Sigma', xSigma, 'NumSigmas', numSigmas);
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.Y = struct('Threshold', numSigmas*ySigma, 'Sigma', ySigma, 'NumSigmas', numSigmas);
				obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.Speed = struct('Threshold', numSigmasSpeed*speedSigma, 'Sigma', speedSigma, 'NumSigmas', numSigmasSpeed);
			end
		end

		function Plot(obj, bodyPart, varargin)
			p = inputParser;
			addRequired(p, 'BodyPart', @(x) isnumeric(x) || ischar(x));
			addParameter(p, 'PlotLikelihood', false, @islogical);
			addParameter(p, 'TLim', [-2 1], @(x) isnumeric(x) || ischar(x));
			parse(p, bodyPart, varargin{:});
			bodyPart		= p.Results.BodyPart;
			plotLikelihood 	= p.Results.PlotLikelihood;
			tLim	 		= p.Results.TLim;

			if ischar(bodyPart)
				iBodyPart = find(strcmpi(bodyPart, {obj(1).VideoTrackingData.BodyPart.Name}));
			elseif isnumeric(bodyPart)
				iBodyPart = bodyPart;
			end

			for iObj = 1:length(obj)
				xSmooth = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XSmooth;
				ySmooth = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YSmooth;
				speedSmooth = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedSmooth;
				xThresholded = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XThresholded;
				yThresholded = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YThresholded;
				speedThresholded = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedThresholded;
				xNormalized = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).XNormalized;
				yNormalized = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).YNormalized;
				speedNormalized = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).SpeedNormalized;
				prob = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Likelihood;
				samplingFreq = (length(obj(iObj).VideoTrackingData.Time) - 1)/seconds(obj(iObj).VideoTrackingData.Time(end) - obj(iObj).VideoTrackingData.Time(1));
				t = seconds(obj(iObj).VideoTrackingData.Time - obj(iObj).VideoTrackingData.Time(1));
				reference = obj(iObj).Events.Reference;
				event = obj(iObj).Events.Event;
				referenceName = obj(iObj).Events.ReferenceName;
				eventName = obj(iObj).Events.EventName;

				f = figure();
				f.OuterPosition = [50 50 1820 980];
				% Plot the whole trace
				ax1 = subplot('Position', [-0.15, 2/3, 1.15, 1/3]);
				ax1.OuterPosition = ax1.Position;
				hold on
				h = plot(ax1, t, xNormalized, 'b'); h.DisplayName = 'X Position (z-score)';
				h = plot(ax1, t, yNormalized, 'r'); h.DisplayName = 'Y Position (z-score)';
				h = plot(ax1, t, speedNormalized, 'k'); h.DisplayName = 'Speed (z-score)';
				yRange = [xNormalized; yNormalized; speedNormalized];
				yRange = prctile(abs(yRange), 95)*[-1, 1];
				for iReference = 1:length(reference)
					h = plot([reference(iReference), reference(iReference)], yRange, 'g:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
				end
				for iEvent = 1:length(event)
					h = plot([event(iEvent), event(iEvent)], yRange, 'r:'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
				end
				if plotLikelihood
					h = scatter(t, speedSmooth, 1*(10-5*prob), 1-prob); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
				end
				hold off
				if plotLikelihood
					colormap(ax1, 'parula')
					colorbar(ax1)
				end
				title(ax1, [obj(iObj).TetrodeRecording.GetExpName(), ' - ', obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Name], 'Interpreter', 'none')
				legend(ax1);
				set(ax1, 'YLim', yRange)

				% Plot traces from trial start to movement, aligned on movement	
				ax21 = subplot('Position', [0, 1/3, 1/4, 1/3]); title('X Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('X (px)')
				ax22 = subplot('Position', [1/4, 1/3, 1/4, 1/3]); title('Y Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Y (px)')
				ax23 = subplot('Position', [2/4, 1/3, 1/4, 1/3]); title('Speed'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Speed (px/s)')
				ax24 = subplot('Position', [3/4, 1/3, 1/4, 1/3]); title('X/Y Position'), zlabel(['Time relative to ', eventName, ' (s)']), xlabel('X (px)'), ylabel('Y (px)')

				ax31 = subplot('Position', [0, 0, 1/4, 1/3]); title('X Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('X (z-score)')
				ax32 = subplot('Position', [1/4, 0, 1/4, 1/3]); title('Y Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Y (z-score)')
				ax33 = subplot('Position', [2/4, 0, 1/4, 1/3]); title('Speed'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Speed (z-score)')
				ax34 = subplot('Position', [3/4, 0, 1/4, 1/3]); title('X/Y Position'), zlabel(['Time relative to ', eventName, ' (s)']), xlabel('X (z-score)'), ylabel('Y (z-score)')

				ax21.OuterPosition = ax21.Position;
				ax22.OuterPosition = ax22.Position;
				ax23.OuterPosition = ax23.Position;
				ax24.OuterPosition = ax24.Position;
				ax31.OuterPosition = ax31.Position;
				ax32.OuterPosition = ax32.Position;
				ax33.OuterPosition = ax33.Position;
				ax34.OuterPosition = ax34.Position;
				hold(ax21, 'on')
				hold(ax22, 'on')
				hold(ax23, 'on')
				hold(ax24, 'on')
				hold(ax31, 'on')
				hold(ax32, 'on')
				hold(ax33, 'on')
				hold(ax34, 'on')

				for iTrial = 1:length(obj(iObj).Trials)
					if obj(iObj).Trials(iTrial).Length >= 4
						color = [.8 .1 .1];
					else
						color = [.1 .8 .1];
					end
					tWindow = obj(iObj).Trials(iTrial).TimeRel;

					data = obj(iObj).Trials(iTrial).BodyPart(iBodyPart);
					vtd = obj(iObj).VideoTrackingData.BodyPart(iBodyPart);

					plot(ax21, tWindow, data.X.Smooth, '-', 'LineWidth', 0.1, 'Color', color);
					plot(ax22, tWindow, data.Y.Smooth, '-', 'LineWidth', 0.1, 'Color', color);
					plot(ax23, tWindow, data.Speed.Smooth, '-', 'LineWidth', 0.1, 'Color', color);
					plot3(ax24, data.X.Smooth, data.Y.Smooth, tWindow, 'Color', color);
					plot(ax31, tWindow, data.X.Normalized, '-', 'LineWidth', 0.1, 'Color', color);
					plot(ax32, tWindow, data.Y.Normalized, '-', 'LineWidth', 0.1, 'Color', color);
					plot(ax33, tWindow, data.Speed.Normalized, '-', 'LineWidth', 0.1, 'Color', color);
					plot3(ax34, data.X.Normalized, data.Y.Normalized, tWindow, 'Color', color);
				end
				% Vertical line at t = 0
				plot(ax21, [0, 0], ax21.YLim, 'k--', 'LineWidth', 2);
				plot(ax22, [0, 0], ax22.YLim, 'k--', 'LineWidth', 2);
				plot(ax23, [0, 0], ax23.YLim, 'k--', 'LineWidth', 2);
				plot(ax31, [0, 0], ax31.YLim, 'k--', 'LineWidth', 2);
				plot(ax32, [0, 0], ax32.YLim, 'k--', 'LineWidth', 2);
				plot(ax33, [0, 0], ax33.YLim, 'k--', 'LineWidth', 2);
				% Plane at t = 0
				[X, Y] = meshgrid(linspace(ax24.XLim(1), ax24.XLim(2), 10), linspace(ax24.YLim(1), ax24.YLim(2), 10));
				surf(ax24, X, Y, zeros(size(X)), 'FaceAlpha', 0.75);
				[X, Y] = meshgrid(linspace(ax34.XLim(1), ax34.XLim(2), 10), linspace(ax34.YLim(1), ax34.YLim(2), 10));
				surf(ax34, X, Y, zeros(size(X)), 'FaceAlpha', 0.75);

				hold(ax21, 'off')
				hold(ax22, 'off')
				hold(ax23, 'off')
				hold(ax24, 'off')
				hold(ax31, 'off')
				hold(ax32, 'off')
				hold(ax33, 'off')
				hold(ax34, 'off')

				set([ax21, ax22, ax23, ax31, ax32, ax33], 'XLim', tLim)
				set([ax24, ax34], 'ZLim', tLim)
				set([ax24, ax34], 'ZDir', 'reverse')
				view(ax24, 45, 30)
				view(ax34, 45, 30)

				numSigmas = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.X.NumSigmas;
				numSigmasSpeed = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.Speed.NumSigmas;
				xThreshold = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.X.Threshold;
				yThreshold = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.Y.Threshold;
				speedThreshold = obj(iObj).VideoTrackingData.BodyPart(iBodyPart).Stats.Speed.Threshold;

				legend(ax21, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(xThreshold)], 'Location', 'best')
				legend(ax22, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(yThreshold)], 'Location', 'best')
				legend(ax23, ['threshold (', num2str(numSigmasSpeed), '\sigma) = ', num2str(speedThreshold)], 'Location', 'best')
				legend(ax31, ['threshold (', num2str(numSigmas), '\sigma)'], 'Location', 'best')
				legend(ax32, ['threshold (', num2str(numSigmas), '\sigma)'], 'Location', 'best')
				legend(ax33, ['threshold (', num2str(numSigmasSpeed), '\sigma)'], 'Location', 'best')
			end
		end

		function Hist(obj, bodyPart, varargin)
			p = inputParser;
			addRequired(p, 'BodyPart', @(x) isnumeric(x) || ischar(x));
			addParameter(p, 'TLim', [-2 1], @(x) isnumeric(x) || ischar(x));
			parse(p, bodyPart, varargin{:});
			bodyPart		= p.Results.BodyPart;
			tLim	 		= p.Results.TLim;

			if ischar(bodyPart)
				iBodyPart = find(strcmpi(bodyPart, {obj(1).VideoTrackingData.BodyPart.Name}));
			elseif isnumeric(bodyPart)
				iBodyPart = bodyPart;
			end

			for iObj = 1:length(obj)
				try
					xTime = zeros(1, length(obj(iObj).Trials));
					yTime = xTime;
					speedTime = xTime;
					for iTrial = 1:length(obj(iObj).Trials)
						data = obj(iObj).Trials(iTrial).BodyPart(iBodyPart);
						iX = find(data.X.Normalized ~= 0, 1);
						iY = find(data.Y.Normalized ~= 0, 1);
						iSpeed = find(data.Speed.Normalized ~= 0, 1);
						if isempty(iX)
							xTime(iTrial) = 0
						else
							xTime(iTrial) = obj(iObj).Trials(iTrial).TimeRel(iX);
						end
						if isempty(iY)
							yTime(iTrial) = 0
						else
							yTime(iTrial) = obj(iObj).Trials(iTrial).TimeRel(iY);
						end
						if isempty(iSpeed)
							speedTime(iTrial) = 0
						else
							speedTime(iTrial) = obj(iObj).Trials(iTrial).TimeRel(iSpeed);
						end
					end
					figure()
					subplot(1, 3, 1)
					histogram(xTime)
					subplot(1, 3, 2)
					histogram(yTime)
					subplot(1, 3, 3)
					histogram(speedTime)
				catch ME
					disp(ME)
					% assignin('base', 'ME', ME)
				end
			end
		end
	end

	methods (Static)
		function va = BatchLoad();
			vtd = VideoAnalysis.GetVideoTrackingData();
			[tr, vtd, expNames] = VideoAnalysis.LoadTetrodeRecording(vtd);
			for iObj = 1:length(tr)
				va(iObj) = VideoAnalysis();
				va(iObj).TetrodeRecording = tr(iObj);
				va(iObj).VideoTrackingData = vtd(iObj);
				va(iObj).ExpName = expNames{iObj};
			end
			fprintf('Done!\n')
		end
		function vtd = GetVideoTrackingData()
			[files, dirname] = uigetfile('C:\SERVER\VideoTracking\*.csv', 'MultiSelect', 'on');
			numFiles = length(files);
			split = cellfun(@(x) strsplit(x, '_'), files, 'UniformOutput', false);

			for iFile = 1:numFiles
				fprintf('Loading video tracking file %d/%d...', iFile, numFiles)

				thisMouse = split{iFile}{1};
				thisDate = split{iFile}{2};
				if length(split{iFile}) < 7
					thisFile = dir(['C:\SERVER\**\', thisMouse, '_', thisDate, '_vidparams.mat']);
				else
					thisCamera = split{iFile}{3};
					thisFile = dir(['C:\SERVER\**\', thisMouse, '_', thisDate, '_', thisCamera, '_vidparams.mat']);
				end

				% Find corresponding crop/trim param file on server
				thisFile = [thisFile.folder, '\', thisFile.name];
				S = load(thisFile);

				vtd(iFile).File = S.File;
				vtd(iFile).Frame = S.Frame;
				vtd(iFile).Time = S.Time;
				vtd(iFile).Crop = S.Crop;

				% Load csv
				thisData = importdata([dirname, files{iFile}]);
				numBodyParts = (size(thisData.data, 2) - 1)/3;
				bodyPartNames = strsplit(thisData.textdata{2, 1}, ',');
				for iBodyPart = 1:numBodyParts
					iCol = 2 + 3*(iBodyPart - 1);
					thisBodyPartName = bodyPartNames{iCol};
					vtd(iFile).BodyPart(iBodyPart).Name = thisBodyPartName;
					vtd(iFile).BodyPart(iBodyPart).X = thisData.data(:, iCol);
					vtd(iFile).BodyPart(iBodyPart).Y = thisData.data(:, iCol + 1);
					vtd(iFile).BodyPart(iBodyPart).Likelihood = thisData.data(:, iCol + 2);
				end

				% If vtd.Time is different length from tracking data
				if length(vtd(iFile).Time) > length(vtd(iFile).BodyPart(1).X)
					vtd(iFile).Time = vtd(iFile).Time((length(vtd(iFile).Time) - length(vtd(iFile).BodyPart(1).X) + 1):end);
				elseif length(vtd(iFile).Time) < vtd(iFile).BodyPart(1).X
					for iBodyPart = 1:numBodyParts
						vtd(iFile).BodyPart(iBodyPart).X = vtd(iFile).BodyPart(iBodyPart).X(1:length(vtd(iFile).Time));
						vtd(iFile).BodyPart(iBodyPart).Y = vtd(iFile).BodyPart(iBodyPart).Y(1:length(vtd(iFile).Time));
						vtd(iFile).BodyPart(iBodyPart).Likelihood = vtd(iFile).BodyPart(iBodyPart).Likelihood(1:length(vtd(iFile).Time));
					end
				end
				fprintf('Done!\n')
			end
		end
		function [tr, vtd, expNames] = LoadTetrodeRecording(vtd)
			expNames = cellfun(@(x) strsplit(x, '\'), {vtd.File}, 'UniformOutput', false);
			expNames = cellfun(@(x) x{end-1}, expNames, 'UniformOutput', false);

			[tr, I] = TetrodeRecording.BatchLoad(expNames);
			vtd = vtd(I);
			expNames = expNames(I);
		end	
	end
end
