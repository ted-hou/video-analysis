function [TR, VTD, I] = loadTetrodeRecording(VTD)
	expNames = cellfun(@(x) strsplit(x, '\'), {VTD.File}, 'UniformOutput', false);
	expNames = cellfun(@(x) x{end-1}, expNames, 'UniformOutput', false);

	[TR, I] = TetrodeRecording.BatchLoad(expNames);
	VTD = VTD(I);
end