function [accdata, triggers, lefttrials, righttrials, fs_new, lefttrialsuccess, righttrialsuccess] = LoadTrainIgor(fname)
% [tbd] = ImportIgorData(fname)
%
% This function takes a file from Igor's dataset and extracts relevant data
%
% arb 29 oct 2014

chL = 'accelL'; % name of left hand channel
chR = 'accelR'; % name of right hand channel

load([fname '.cfg'],'-mat');
[Nch,chnm] = uichannelsettings(fname);
itarg = strmatch('targets',chnm); if ~UI.plot_fdb, error('no behavior logged to file'); end
irew = strmatch('reward',chnm);
iL = strmatch(chL,chnm); if isempty(iL), error('chL: no channel found with that name'); end
iR = strmatch(chR,chnm); if isempty(iR), error('chR: no channel found with that name'); end
itrig = strmatch('trig',chnm); %if isempty(itrig), error('no trigger channel found'); end

fid = fopen([fname '.bin'],'r'); % load data
fseek(fid,0,'eof');
nbytes = ftell(fid); % number of bytes in file
N = nbytes/4/Nch; % number of samples per channel (4 bytes per single-precision sample)
fseek(fid,0,'bof');

fseek(fid, (iL-1)*4, 'bof'); % offset to start of accel channel
lacceldat = fread(fid, N, 'single', 4*(Nch-1));

fseek(fid, (iR-1)*4, 'bof'); % offset to start of accel channel
racceldat = fread(fid, N, 'single', 4*(Nch-1));

%%%% downsample accel data
fs_target = 333; % hz
downsampleby = round(UI.samprate/fs_target); % take every "downsampleby" samples
fs_new = UI.samprate/downsampleby;

lacceldat = decimate(lacceldat, downsampleby);
racceldat = decimate(racceldat, downsampleby);

%% collect rest of data

fseek(fid, (itarg-1)*4, 'bof'); % offset to start of target channel
bindata = fread(fid, N, 'single', 4*(Nch-1));
lefttrials = u.findOnsetsAndOffsets(bindata==1);
righttrials = u.findOnsetsAndOffsets(bindata==2);
clear bindata

fseek(fid, (itrig(1)-1)*4, 'bof'); % offset to start of trigger channel
trigdat = fread(fid, N, 'single', 4*(Nch-1));
triggers = find(trigdat/1e3>100); % > 100mV
clear trigdat

% fseek(fid, (irew-1)*4, 'bof'); % offset to start of reward channel
% rewdat = fread(fid, N, 'single', 4*(Nch-1));
% rewards = find(diff(rewdat)>0.5)+1;% reward indices
% clear rewdat

%convert all to ms
lefttrials = 1000*lefttrials/UI.samprate;
righttrials = 1000*righttrials/UI.samprate;
triggers = 1000*triggers/UI.samprate;
%rewards = 1000*rewards/UI.samprate;

righttrialsuccess = ones(size(righttrials,1),1);
lefttrialsuccess = ones(size(lefttrials,1),1);

if sum(diff(lefttrials,1,2)==0>3), error('what the hell'); % if there are more than 3 bad trials in a giving recording, throw an error
end

%make other outputs that we dont have
accdata = [lacceldat(:), racceldat(:)];

accdata = accdata/1e3; % scale to mV

fclose(fid);


function [Nch,chnm,chgu] = uichannelsettings(cfgfile)
% function [Nch,chnm,chgu] = uichannelsettings(cfgfile)
%   Read user-interface settings in *.cfg files generated by various
%   gUSBamp programs to determine number and names of channels.
load([cfgfile '.cfg'],'-mat');
Nch = length(find(UI.ch_enabled))+length(find(UI.ga_trigger)); % number of channels
if isfield(UI,'plot_fdb'), Nch = Nch+1; end
if isfield(UI,'plot_fdb') && str2double(cfgfile(end-10:end-3))>=20120202, Nch = Nch+1; end
chnm = cell(Nch,1); % name of channels
chgu = zeros(Nch,1); % gUSBamp that channel was recorded on
ii = 0;
for iga = 1:length(UI.ga_trigger)
    ind = find(UI.ch_enabled(iga,:));
    chnm(ii+1:ii+length(ind)) = UI.ch_name(iga,ind)';
    chgu(ii+1:ii+length(ind)) = iga*ones(length(ind),1);
    ii = ii + length(ind);
    if UI.ga_trigger(iga), chnm{ii+1} = ['trig ' num2str(iga)]; chgu(ii+1) = iga; ii = ii + 1; end
end
if isfield(UI,'plot_fdb'), chnm{ii+1} = 'targets'; chgu(ii+1) = NaN; end
if isfield(UI,'plot_fdb') && str2double(cfgfile(end-10:end-3))>=20120202, chnm{ii+2} = 'reward'; chgu(ii+2) = NaN; end