function [d, etime] = mcreadeye(fn)
% Reads data of an Ergoneers eye tracker and stores the data as a mocap
% norm data structure.
% BETA version. To be used with caution.
%
% syntax
% d = mcreadeye(fn);
% [d, etime] = mcreadeye(fn)
%
% input parameters
% fn: file name (.txt); as of now only the Ergoneers eye tracker is supported. 
% If no input parameter is given, a file open dialog opens.
%
% output
% d: norm data structure including eye data and parameters as specified in the
% Ergoneers export file
% etime: sample points
% 
% examples
% d = mcreadeye(e);
%
% comments
% Only Ergoneers eye trackers are supported as of now.
%
% see also
% mcread
%
% ? Part of the Motion Capture Toolbox, Copyright ?2008,
% University of Jyvaskyla, Finland

d=[];

ifp = fopen(fn);
if ifp<0
    disp(['Could not open file ' fn]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return;
end

if ~ischar(fn) %Check if input is given as string
    disp([10, 'Please enter file name as string!',10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return
end

d.type = 'norm data';
d.filename = fn;
d.nFrames = [];
d.nCameras = 1;
d.nMarkers = [];
d.freq=[];
d.nAnalog = 0;
d.anaFreq = 0;
d.timederOrder = 0;


e=textscan(ifp,'%s', 'Delimiter', '\t'); %read the whole file

if ~strcmp(e{1}{1},'rec_time')
    disp([10, 'Cannot open file. It does not seem to be an Ergoneers file.',10]);
    [y,fs] = audioread('mcsound.wav');
    sound(y,fs);
    return
end
    


for k=3:14 %short header without processed data...
    d.markerName{k-2,1}=e{1}{k};
end


if size(e{1}{k+1},2) > 12 %long header with processed data...
    for k=15:24
        d.markerName{k-2,1}=e{1}{k};
    end
end




%time point and data
d.data=[];
ed=e{1}((k+1):end); 
edata=[];
etime=[];
for n=1:k:length(ed)    
    ed1=cell2mat(ed(n));
    etime=[etime;str2double(ed1([5 7:12]))]; %time
    if etime(end) > 100
        etime(end) = etime(end)-40; %this might fail if recordings are longer than two minutes...
    end
    edd=str2double(ed(n+2:n+(k-1)));
    edata=[edata;edd'];
end



d.freq = round(1/((etime(end)-etime(1))/length(etime)));

%Dlab adds (instead of deleting) frames if gap-filled manually, this finds and removes them
%(removing the added time stamp and replacing the original value with the 
% gap-filled value.)
if d.freq ~= 50
    samplind=0;
    for m=2:length(etime)
        sampldiff = etime(m)*100 - etime(m-1)*100;
        if round(sampldiff) ~= 2
            if m-samplind(end)==1 %to skip every second entry in case of fills
                continue
            end
            samplind = [samplind,m];
        end
    end
    samplind=samplind(1,2:end);
    edata(samplind-1,:)=[];
    etime(samplind)=[];    
    d.freq = round(1/((etime(end)-etime(1))/length(etime)));
end


d.data=edata;

d.nFrames = size(d.data,1);
d.nMarkers = size(d.data,2);

fclose(ifp);

d.analogdata = [];
d.other = [];