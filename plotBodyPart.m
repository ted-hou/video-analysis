function plotBodyPart(iTr, vtd, tr)
	posX = [vtd(iTr).BodyPart(2).X];
	posY = [vtd(iTr).BodyPart(2).Y];

	pos = [0; sqrt(diff(posX).^2 + diff(posY).^2)];

	prob = [vtd(iTr).BodyPart(2).Likelihood];

	samplingFreq = (length(vtd(iTr).Time) - 1)/seconds(vtd(iTr).Time(end) - vtd(iTr).Time(1));
	t = milliseconds(vtd(iTr).Time - vtd(iTr).Time(1));
	cutOffFreq = 0.001;

	% Get first press times
	reference = tr(iTr).DigitalEvents.CueOn;
	event = tr(iTr).DigitalEvents.PressOn;
	edges = [reference(1:end - 1), max(event(end), reference(end))];
	[~, ~, bins] = histcounts(event, edges);
	event = event(bins ~= 0);
	bins = nonzeros(bins);
	[iReference, iEvent] = unique(bins, 'first');
	reference = reference(iReference);
	event = event(iEvent);

	figure()
	hold on
	plot(t, lowpass(pos, cutOffFreq, samplingFreq), 'k')
	scatter(t, lowpass(pos, cutOffFreq, samplingFreq), 1*(10-5*prob), 1-prob)
	plot(milliseconds(tr(iTr).GetStartTime() + seconds(event) - vtd(iTr).Time(1)), 0, 'ro')
	hold off
	colormap('parula')