function [dt et] = mcsyncmocap2eye(varargin)
% Syncs mocap and eye tracker data based on nod performed in the beginning of
% the recording (more information in comment below). 
% The mocap marker used has to be the first marker appearing in the
% mocap structure (i.e. head).
% Eye tracker data has to conform to the regular export file structure by
% Ergoneers.
% BETA version. To be used with caution.
%
% syntax
% [dt et] = mcsyncmocap2eye(d, e)
% [dt et] = mcsyncmocap2eye(d, e, 'thm', thvm)
% [dt et] = mcsyncmocap2eye(d, e, 'the', thve)
% [dt et] = mcsyncmocap2eye(d, e, 'sp', spv)
% [dt et] = mcsyncmocap2eye(d, e, 'thm', thvm, 'sp', spv)
% [dt et] = mcsyncmocap2eye(d, e, 'the', thve, 'sp', spv)
% [dt et] = mcsyncmocap2eye(d, e, 'thm', thvm, the', thve, 'sp', spv)
%
% input parameters
% d: original mocap data
% e: original eye data
% thvm: Threshold for detecting the sync point in the mocap data, default 2. 
% (value can begiven either as a positive or negative value)
% thve: Threshold for detecting the sync point in the pupil data, default 2. 
% (value can begiven either as a positive or negative value)
% spv: sync point, default 0: syncs to the beginning of the eye tracker; 
% 1: syncs both data sets to the down peak of the nod
%
% output
% dt: trimmed mocap data
% et: trimmed eye data
% 
% examples
% [dt et] = mcsyncmocap2eye(d, e);
% [dt et] = mcsyncmocap2eye(d, e, 'th', 2.5, 'sp', 1);
%
% comments
% Eye tracker and mocap are synced based on a nod that the participant 
% performs in the beginning of the recording. Mocap recording needs to be 
% started before eye tracker recording.The approach is described in the 
% following publication. Please refer to the paper to use the method:
% 
% see also
% mcreadeye
%
% ? Part of the Motion Capture Toolbox, Copyright ?2008,
% University of Jyvaskyla, Finland

dt=[];
et=[];

%checking that inputs are correct
if nargin<2
    disp([10, 'Not enough input arguments for this function.', 10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return
end

%setting required and default values
d=varargin{1};
e=varargin{2};
thvm=-2;
thve=-2;
spv=0;


if isfield(d,'type') && strcmp(d.type, 'MoCap data') || isfield(d,'type') && strcmp(d.type, 'norm data')
else disp([10, 'The first input argument has to be a variable with valid mocap toolbox data structure.', 10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return;
end

if isfield(e,'type') && strcmp(e.type, 'norm data')
else disp([10, 'The second input argument has to be a variable with valid norm data structure.', 10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return;
end

if mod(nargin,2)==1
    disp([10, 'Number of input arguments do not fit with function requirement.', 10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return
end

for k=3:2:length(varargin)
    if strcmp(varargin{k}, 'thm')
        thvm=varargin{k+1};
    elseif strcmp(varargin{k}, 'the')
        thve=varargin{k+1};
    elseif strcmp(varargin{k}, 'sp')
        spv=varargin{k+1};
    else
        str=sprintf('Input argument %s unknown. Default values are used for thresholds (2) and sync point (0).', varargin{k});
        disp([10, str, 10])
        thvm=-2;
        thve=-2;
        spv=0;
    end
end

if thvm>0 %in case threshold is given as positive value
    thvm=thvm*(-1);
end

if thve>0 %in case threshold is given as positive value
    thve=thve*(-1);
end

if spv ~= 0 && spv ~= 1
    spv = 1;
    disp([10, 'Value of sync point set to 1. Data trimmed to nod.', 10]);
end


% detecting the nods
%mocap data (head marker)
d=mcfillgaps(d, 'fillall');
dv=mctimeder(d); %calculating velocity
dv.data(1:180,3)=0; %setting first 1.5 seconds to 0
dv.data(:,3)=zscore(dv.data(:,3)); %z-scoring the data

for n=1:length(dv.data(:,3))-1
    if dv.data(n,3) < thvm %threshold
        if dv.data(n,3) < dv.data(n-1,3)
            if dv.data(n,3) < dv.data(n+1,3)
                for h=n:length(dv.data(:,3))-1
                    if dv.data(h,3) > 0
                        mcmvf = (h-1)/200; % get "zero-crossig"
                        break;
                    end
                end
                break;
            end
        end
    end
end

%pupil data (y axis)
if e.nMarkers==12 %no manual gap-filling performed in Dlab
    ts=2;
else
    ts=12; %manual gapfilling performed in Dlab
end
e.data(e.data==0)=NaN; %setting 0 to NaN (for gap-filling)
e=mcfillgaps(e, 'fillall');
ev=mctimeder(e); %calculating velocity
ev.data(1:50,ts)=0; %setting first second to 0
ev.data(:,ts)=zscore(ev.data(:,ts)); %z-scoring

for n=1:length(ev.data(:,ts))-1
    if ev.data(n,ts) < thve %threshold
        if ev.data(n,ts) < ev.data(n-1,ts)
            if ev.data(n,ts) < ev.data(n+1,ts)
                for h=n:length(ev.data(:,ts))-1
                    if ev.data(h,ts) > 0
                        etmvf = (h-1)/50; % get "zero-crossing"
                        break;
                    end
                end
                break;
            end
        end
    end
end

%trimming
if spv == 0 %trim mocap to start of eye recording
    dt=mctrim(d, round((mcmvf-etmvf)*d.freq), d.nFrames, 'frame');
    et=e;
end

if spv == 1 %trim mocap and eye to the down peak of the nod
    dt=mctrim(d, mcmvf*d.freq, d.nFrames, 'frame');
    et=mctrim(e, etmvf*e.freq, e.nFrames, 'frame');
end

