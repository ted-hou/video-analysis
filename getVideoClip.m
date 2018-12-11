function clip = getVideoClip(vtd, tr, trTime, numFramesBefore, numFramesAfter)
	if nargin < 5
		numFramesAfter = 60;
	end
	if nargin < 4
		numFramesBefore = 120;
	end

	v = VideoReader([vtd.File, '_cropped.mp4']);
	vidStartTime = v.CurrentTime;

	clip = cell(length(trTime), 1);

	for iClip = 1:length(trTime)
		fprintf('Extracting clip %d of %d...', iClip, length(trTime))
		[~, iFrame] = min(abs(seconds(vtd.Time - tr.GetStartTime()) - trTime(iClip)));
		v.CurrentTime = (iFrame - 1 - numFramesBefore)/v.FrameRate + vidStartTime;

		clip{iClip} = uint8(zeros(v.Height, v.Width, 3, numFramesBefore + numFramesAfter + 1));
		labelColors = [169, 229, 187; 252, 246, 177; 247, 179, 43; 247, 44, 37; 63, 124, 172; 255, 107, 53; 181, 148, 182];
		for iClipFrame = 1:size(clip{iClip}, 4)
			thisFrame = readFrame(v);
			iFrameAbs = iFrame + iClipFrame - numFramesBefore - 1;
			position = transpose([cellfun(@(x) x(iFrameAbs), {vtd.BodyPart.X}); cellfun(@(x) x(iFrameAbs), {vtd.BodyPart.Y})]);
			likelihood = round(100*transpose(cellfun(@(x) x(iFrameAbs), {vtd.BodyPart.Likelihood})))/100;
			labels = {vtd.BodyPart.Name};
			thisFrame = insertText(thisFrame, position, labels, 'TextColor', labelColors, 'BoxOpacity', 0, 'AnchorPoint', 'RightTop');
			thisFrame = insertText(thisFrame, position, likelihood, 'TextColor', labelColors, 'BoxOpacity', 0, 'AnchorPoint', 'RightBottom');
			thisFrame = insertMarker(thisFrame, position, 'Color', labelColors, 'Size', 10);
			clip{iClip}(:, :, :, iClipFrame) = thisFrame;
		end
		fprintf('Done!\n')
	end
