function varargout = plotBodyPart(vtd, tr, iTr, varargin)
	p = inputParser;
	addRequired(p, 'VTD');
	addRequired(p, 'TR');
	addRequired(p, 'iTr', @isnumeric);
	addRequired(p, 'iBodyPart', @isnumeric);
	addParameter(p, 'PlotLikelihood', false, @islogical);
	addParameter(p, 'Reference', 'CueOn', @ischar);
	addParameter(p, 'Event', 'PressOn', @ischar);
	addParameter(p, 'TLim', [-2 1], @(x) isnumeric(x) || ischar(x));
	addParameter(p, 'Window', [2 2], @isnumeric);
	addParameter(p, 'SmoothingWindow', [2 2], @isnumeric);
	addParameter(p, 'SmoothingMethod', 'movmean', @ischar);
	addParameter(p, 'NumSigmas', 6, @isnumeric);
	parse(p, vtd, tr, iTr, varargin{:});
	vtd				= p.Results.VTD;
	tr 				= p.Results.TR;
	iTr				= p.Results.iTr;
	iBodyPart		= p.Results.iBodyPart;
	plotLikelihood 	= p.Results.PlotLikelihood;
	referenceName 	= p.Results.Reference;
	eventName	 	= p.Results.Event;
	tLim	 		= p.Results.TLim;
	window			= p.Results.Window;
	smoothingWindow	= p.Results.SmoothingWindow;
	smoothingMethod	= p.Results.SmoothingMethod;
	numSigmas		= p.Results.NumSigmas;


	x = [vtd(iTr).BodyPart(iBodyPart).X];
	y = [vtd(iTr).BodyPart(iBodyPart).Y];

	prob = [vtd(iTr).BodyPart(iBodyPart).Likelihood];

	samplingFreq = (length(vtd(iTr).Time) - 1)/seconds(vtd(iTr).Time(end) - vtd(iTr).Time(1));
	t = seconds(vtd(iTr).Time - vtd(iTr).Time(1));

	% Interpolate missing positions
	xLowPass = x;
	yLowPass = y;
	isMissing = x <= 10 & y <= 10;
	xLowPass(isMissing) = nan;
	yLowPass(isMissing) = nan;
	xLowPass = fillmissing(xLowPass, 'linear');
	yLowPass = fillmissing(yLowPass, 'linear');

	if ~isempty(smoothingWindow)
		xLowPass = smoothdata(xLowPass, smoothingMethod, smoothingWindow);
		yLowPass = smoothdata(yLowPass, smoothingMethod, smoothingWindow);
	end

	speed = [0; sqrt(diff(xLowPass).^2 + diff(yLowPass).^2)];
	speedLowPass = speed;

	xSigma = median(abs(xLowPass - median(xLowPass)))/0.6745;
	ySigma = median(abs(yLowPass - median(yLowPass)))/0.6745;
	speedSigma = median(abs(speedLowPass - median(speedLowPass)))/0.6745;

	xDenoised = xLowPass;
	yDenoised = yLowPass;
	speedDenoised = speedLowPass;
	xDenoised(abs(xLowPass - median(xLowPass)) < numSigmas*xSigma) = median(xLowPass);
	yDenoised(abs(yLowPass - median(yLowPass)) < numSigmas*ySigma) = median(yLowPass);
	speedDenoised(abs(speedLowPass - median(speedLowPass)) < numSigmas*speedSigma) = median(speedLowPass);

	% Get first press times
	reference = tr(iTr).DigitalEvents.(referenceName);
	event = tr(iTr).DigitalEvents.(eventName);
	edges = [reference(1:end - 1), max(event(end), reference(end))];
	[~, ~, bins] = histcounts(event, edges);
	event = event(bins ~= 0);
	bins = nonzeros(bins);
	[iReference, iEvent] = unique(bins, 'first');
	reference = reference(iReference);
	event = event(iEvent);

	reference = seconds(tr(iTr).GetStartTime() + seconds(reference) - vtd(iTr).Time(1));
	event = seconds(tr(iTr).GetStartTime() + seconds(event) - vtd(iTr).Time(1));

	figure()
	% Plot the whole trace
	ax1 = subplot('Position', [-0.15, 2/3, 1.15, 1/3]);
	ax1.OuterPosition = ax1.Position;
	hold on
	h = plot(ax1, t, xLowPass - median(xLowPass), 'b--'); h.DisplayName = 'X Position (px)';
	h = plot(ax1, t, yLowPass - median(yLowPass), 'r--'); h.DisplayName = 'Y Position (px)';
	h = plot(ax1, t, speedLowPass - median(speedLowPass), 'k--'); h.DisplayName = 'Speed (px/s)';
	h = plot(ax1, t, xDenoised - median(xDenoised), 'b'); h.DisplayName = 'X Position (spike only) (px)';
	h = plot(ax1, t, yDenoised - median(yDenoised), 'r'); h.DisplayName = 'Y Position (spike only) (px)';
	h = plot(ax1, t, speedDenoised - median(speedDenoised), 'k'); h.DisplayName = 'Speed (spike only) (px)';
	yRange = [speedLowPass - median(speedLowPass); xLowPass - median(xLowPass); yLowPass - median(yLowPass)];
	yRange = [min(yRange), max(yRange)];
	for iReference = 1:length(reference)
		h = plot([reference(iReference), reference(iReference)], yRange, 'g'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
	end
	for iEvent = 1:length(event)
		h = plot([event(iEvent), event(iEvent)], yRange, 'r'); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
	end
	if plotLikelihood
		h = scatter(t, speedLowPass, 1*(10-5*prob), 1-prob); h.Annotation.LegendInformation.IconDisplayStyle = 'off';
	end
	hold off
	if plotLikelihood
		colormap(ax1, 'parula')
		colorbar(ax1)
	end
	title(ax1, [tr(iTr).GetExpName(), ' - ', vtd(iTr).BodyPart(iBodyPart).Name], 'Interpreter', 'none')
	legend(ax1);
	set(ax1, 'YLim', [-50, 50])

	% Plot traces from trial start to movement, aligned on movement	
	ax21 = subplot('Position', [0, 1/3, 1/4, 1/3]); title('X Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('X (px)')
	ax22 = subplot('Position', [1/4, 1/3, 1/4, 1/3]); title('Y Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Y (px)')
	ax23 = subplot('Position', [2/4, 1/3, 1/4, 1/3]); title('Speed'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Speed (px/s)')
	ax24 = subplot('Position', [3/4, 1/3, 1/4, 1/3]); title('X/Y Position'), zlabel(['Time relative to ', eventName, ' (s)']), xlabel('X (px)'), ylabel('Y (px)')

	ax31 = subplot('Position', [0, 0, 1/4, 1/3]); title('X Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('X (px)')
	ax32 = subplot('Position', [1/4, 0, 1/4, 1/3]); title('Y Position'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Y (px)')
	ax33 = subplot('Position', [2/4, 0, 1/4, 1/3]); title('Speed'), xlabel(['Time relative to ', eventName, ' (s)']), ylabel('Speed (px/s)')
	ax34 = subplot('Position', [3/4, 0, 1/4, 1/3]); title('X/Y Position'), zlabel(['Time relative to ', eventName, ' (s)']), xlabel('X (px)'), ylabel('Y (px)')

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

	for iTrial = 1:length(reference)
		if event(iTrial) - reference(iTrial) >= 4
			color = [.8 .1 .1];
		else
			color = [.1 .8 .1];
		end
		inWindow = t >= reference(iTrial) + window(1) & t <= event(iTrial) + window(2);
		tWindow = t(inWindow) - event(iTrial);
		xWindow = xLowPass(inWindow);
		yWindow = yLowPass(inWindow);
		speedWindow = speedLowPass(inWindow);

		plot(ax21, tWindow, xLowPass(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot(ax22, tWindow, yLowPass(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot(ax23, tWindow, speedLowPass(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot3(ax24, xLowPass(inWindow), yLowPass(inWindow), tWindow, 'Color', color);
		plot(ax31, tWindow, xDenoised(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot(ax32, tWindow, yDenoised(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot(ax33, tWindow, speedDenoised(inWindow), '-', 'LineWidth', 0.1, 'Color', color);
		plot3(ax34, xDenoised(inWindow), yDenoised(inWindow), tWindow, 'Color', color);
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

	legend(ax21, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(xSigma)], 'Location', 'best')
	legend(ax31, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(xSigma)], 'Location', 'best')
	legend(ax22, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(ySigma)], 'Location', 'best')
	legend(ax32, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(ySigma)], 'Location', 'best')
	legend(ax23, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(speedSigma)], 'Location', 'best')
	legend(ax33, ['threshold (', num2str(numSigmas), '\sigma) = ', num2str(speedSigma)], 'Location', 'best')

	varargout = {xLowPass, yLowPass, speedLowPass, x, y, speed, t, reference, event};
end