function s_ms_directions_150(trackingType)
%
% Load FE structeres obtained by preprocessing connectomesconstrained within a
% region of interest and within the cortex and makes some basic plot of
% statistics in the connectomes
%
% See also:

% Get the base directory for the data
datapath = '/marcovaldo/frk/2t2/predator/';
subjects = {'FP_150dirs_b1000_2000_4000_2iso'};

if notDefined('saveDir'), savedir = fullfile('/marcovaldo/frk/Dropbox','pestilli_etal_revision',mfilename);end
if notDefined('trackingType'), trackingType = 'lmax10';end
if notDefined('numDirs'), numDirs = [150:-5:10];end
addpath(genpath('/marcovaldo/frk/git/boot_dwi'))

% Bins for the fiber density estimates
xBins = [1 2 4 8 16 32 64 128 256 512 1024 2048];
x     = 1:length(xBins);

% Bins for the sum of weights estimates
wxBins = [.9./(2.^[10:-1:1]) ];
wx     = 1:length(wxBins);

doFD       = 1;
figVisible = 'off';
probIndex = 1; %for 2000bval, Deterministic index 2: for 200 bval

for isbj = 1:length(subjects)
    % High-resolution Anatomy
    saveDir = fullfile(savedir,subjects{isbj});
    
    % File to load   
    connectomesPath   = fullfile(datapath,subjects{isbj},'connectomes');
    feFileToLoad = dir(fullfile(connectomesPath,sprintf('*%s*.mat',trackingType)));
    fname = feFileToLoad(probIndex).name(1:end-4);
    feFileToLoad = fullfile(connectomesPath,fname);
    fprintf('[%s] Loading: \n%s\n ======================================== \n\n',mfilename,feFileToLoad)
    load(feFileToLoad);
    fprintf('[%s] Extracting info: \n%s\n ======================================== \n\n',mfilename,feFileToLoad)
    
fprintf('[%s] Extracting info: \n%s\n ======================================== \n\n',mfilename,feFileToLoad)
    for iNumDirs = 1:length(numDirs)    
        xform   = feGet(fe,'xform img 2 acpc');
        mapsize = feGet(fe, 'map size');
        nBvecs = feGet(fe,'nbvecs');
        nBvals = fe.life.imagedim(4) - nBvecs;
        nVoxels= feGet(fe,'nvoxels');
        if isempty(fe.rep)
            if ~isempty(strfind(fe.path.dwifilerep,'home'))
             fe.path.dwifilerep = fullfile('/marcovaldo/',fe.path.dwifilerep(strfind(fe.path.dwifilerep,'home')+length('home'):end));
            end
            fe = feConnectomeSetDwi(fe,fe.path.dwifilerep,true);
        end
        rmseM = feGetRep(fe, 'vox rmse');
        rmseD = feGetRep(fe, 'vox rmse data');
        rmseR = feGetRep(fe, 'vox rmse ratio');
        if isempty(fe.fg)
            fe.path.savedir = fullfile('/marcovaldo/',fe.path.savedir(strfind(fe.path.savedir,'home')+length('home'):end));
            fiberPath = fullfile(fileparts(fe.path.savedir),'fibers');
            fibers    = dir(fullfile(fiberPath,sprintf('*%s*.pdb',trackingType)));
            fe = feSet(fe,'fg from acpc',fgRead(fullfile(fiberPath,fibers.name)));
        end
        w       = feGet(fe,'fiber weights');
        
        % Compute the total number of fibers retained at each direction number.
        m.optimized.nfibers(iNumDirs,isbj) = sum(w > 0);
        m.optimized.ndirs(iNumDirs,isbj)   = numDirs(iNumDirs);
        
        numFibers_total(iNumDirs,isbj) = length(w);
        numFibers_good(iNumDirs,isbj)  = sum(w > 0);
        
        fgOpt   = fgExtract(feGet(fe,'fibers acpc'),w > 0,'keep');
        m.nfibers.y(iNumDirs,isbj)        = numFibers_good(iNumDirs,isbj);
        m.rmse.dataMean(iNumDirs,isbj)    = mean(rmseD);
        m.rmse.modelMean(iNumDirs,isbj)   = mean(rmseM);
        m.rmse.dataMedian(iNumDirs,isbj)  = median(rmseD);
        m.rmse.modelMedian(iNumDirs,isbj) = median(rmseM);
        m.rrmse.mean(iNumDirs,isbj)       = mean(rmseR);
        m.rrmse.median(iNumDirs,isbj)     = median(rmseR);

        %theseIndices = randsample(1:nBvecs,numDirs(iNumDirs));
        if numDirs(iNumDirs) < size(fe.life.bvecs,1)
           [~, theseIndices] = bd_subsample(fe.life.bvecs',numDirs(iNumDirs));
        else
            theseIndices = 1:numDirs(iNumDirs);
        end
          
        % Update the FE structure fields that depend on the bvecs
        fe.life.bvecs = fe.life.bvecs(theseIndices,:);
        %if ~all(all(fe.life.bvecs==sample_bvecs));keyboard,end
        
        fe.life.bvals        = fe.life.bvals(theseIndices);
        fe.life.bvecsindices = fe.life.bvecsindices(theseIndices);
        fe.life.diffusion_signal_img = fe.life.diffusion_signal_img(:,theseIndices);
        fe.life.imagedim(end)        = numDirs(iNumDirs) + nBvals;
        
        fe.rep.bvecs = fe.rep.bvecs(theseIndices,:);
        fe.rep.bvals = fe.rep.bvals(theseIndices);
        fe.rep.bvecsindices = fe.rep.bvecsindices(theseIndices);
        fe.rep.diffusion_signal_img = fe.rep.diffusion_signal_img(:,theseIndices);
        fe.rep.diffusion_S0_img     = fe.rep.diffusion_S0_img(theseIndices);
        fe.rep.imagedim(end)        = numDirs(iNumDirs) + nBvals;
        
        directionsIndices = false(nBvecs,1);
        directionsIndices(theseIndices) = true;
        allIndices = repmat(directionsIndices,nVoxels,1);
        fe.life.Mfiber = fe.life.Mfiber(allIndices,:);
        fe.life.dSig = fe.life.dSig(allIndices);
        fe   = feSet(fe,'fit',feFitModel(fe.life.Mfiber,fe.life.dSig','bbnnls'));
        
       if doFD
            fprintf('[%s] Computing fiber density: \n%s\n ======================================== \n\n',mfilename,feFileToLoad)
            % Get the fiber density
            % fd = feGet(fe,'fiber density');
            fdImg  = dtiComputeFiberDensityNoGUI(feGet(fe,'fibers acpc'), xform, mapsize);
            fdOImg = dtiComputeFiberDensityNoGUI(fgOpt, xform, mapsize);
        end

    fprintf('[%s] Making histrograms: \n%s\n ======================================== \n\n',mfilename,feFileToLoad)
    
    % Histogram plots
    fdImg(fdImg==0) = nan;    
    fdOImg(fdOImg==0) = nan;
    m.density.candidate_mean(iNumDirs,isbj)       = nanmean(   fdImg(:));
    m.density.candidate_median(iNumDirs,isbj)     = nanmedian( fdImg(:));
    m.density.optimal_mean(iNumDirs,isbj)         = nanmean(  fdOImg(:));
    m.density.candidate_median(iNumDirs,isbj)     = nanmedian(fdOImg(:));
    
    x = [1 2.^[1 2 3 4 5 6 7 8 9 10]];
    x = [2:2:512];
    [yFD(iNumDirs,isbj,:), xFD(iNumDirs,isbj,:)]  = hist(fdImg(:),x);
     yFD(iNumDirs,isbj,:) = 100*yFD(iNumDirs,isbj,:)./sum(yFD(iNumDirs,isbj,:));
    [yoFD(iNumDirs,isbj,:),xoFD(iNumDirs,isbj,:)]= hist(fdOImg(:),x);
     yoFD(iNumDirs,isbj,:) = 100*yoFD(iNumDirs,isbj,:)./sum(yoFD(iNumDirs,isbj,:));
     
    x   = 0:10:400;
    [yRMSE(iNumDirs,isbj,:),xRMSE(iNumDirs,isbj,:)]  = hist(rmseD(:),x);
    yRMSE(iNumDirs,isbj,:) = 100*yRMSE(iNumDirs,isbj,:)./sum(yRMSE(iNumDirs,isbj,:));
    [yoRMSE(iNumDirs,isbj,:),xoRMSE(iNumDirs,isbj,:)]= hist(rmseM(:),x);    
    yoRMSE(iNumDirs,isbj,:) = 100*yoRMSE(iNumDirs,isbj,:)./sum(yoRMSE(iNumDirs,isbj,:));

    x   = logspace(-.3,.3,32);
    [yRrmse(iNumDirs,isbj,:),xRrmse(iNumDirs,isbj,:)]  = hist(rmseR(:),x);
    yRrmse(iNumDirs,isbj,:) = 100*(yRrmse(iNumDirs,isbj,:)./sum(yRrmse(iNumDirs,isbj,:)));
    
    clear fdOImg fdImg 
    end
end
m.nfibers.x = numDirs;

% Average histograms
saveDir = fullfile(savedir,'average_150_2mm');

% Save the results to file, it takes along time to load all these FE strctures...
%m.density.candidatey  = squeeze(mean(yFD,2));
%m.density.candidateSte= squeeze(std(yFD,[],2)./sqrt(size(yFD,2)));
%m.density.optimaly    = squeeze(mean(yoFD,2));
%m.density.optimalSte  = squeeze(std(yoFD,[],2)./sqrt(size(yoFD,2)));
%m.density.x = squeeze(xFD(:,isbj,:));
m.density.units = {'x=Fascicles per voxel','y=percent voxels'};
m.density.yFD=yFD;
m.density.yoFD=yoFD;

% rmse data vs. model
m.rmse.data    = squeeze(mean(yRMSE,2));
m.rmse.dataSte = squeeze(std(yRMSE,[],2)./sqrt(size(yRMSE,2)));
m.rmse.model   = squeeze(mean(yoRMSE,2));
m.rmse.modelSte= squeeze(std(yoRMSE,[],2)./sqrt(size(yoRMSE,2)));
m.rmse.x       = squeeze(xRMSE(:,isbj,:));
m.rmse.units = {'x=rmse (raw scanner units)','y=percent voxels'};
m.rmse.yRMSE=yRMSE;
m.rmse.yoRMSE=yoRMSE;

% rmse data vs. model
m.rrmse.y   = squeeze(mean(yRrmse,2));
m.rrmse.ste = squeeze(std(yRrmse,[],2)./sqrt(size(yRrmse,2)));
m.rrmse.x   = squeeze(xRrmse(:,isbj,:));
m.rrmse.units = {'x=Rrmse (a.u.)','y=percent voxels'};
m.rrmse.yRrmse=yRrmse;

mkdir(saveDir)
save(fullfile(saveDir,'mean_histograms_steps10.mat'),'m','numFibers_total','numFibers_good')

% Histogram plots
figName = sprintf('FibDensHistCandVSOpt_NDirs%i_%i_%i_%i_%i_%s',numDirs,  fname(1:39));
colors = {[.9 .3 .3],[.9 .45 .35],[.9 .55 .5],[.9 .6 .6],[.9 .8 .8]};
fh  = figure('name',figName,'visible',figVisible,'color','w');
for iNDirs = 1:size(m.density.x,1)
semilogx(m.density.x(iNDirs, :),m.density.candidatey(iNDirs, :),'k-','linewidth',2);
hold on
semilogx([m.density.x(iNDirs, :);m.density.x(iNDirs, :)], [m.density.candidatey(iNDirs, :)-m.density.candidateSte(iNDirs, :); ...
                                     m.density.candidatey(iNDirs, :)+m.density.candidateSte(iNDirs, :)],'k-');
semilogx(m.density.x(iNDirs, :),m.density.optimaly(iNDirs, :),'r-','linewidth',2, 'color',colors{iNDirs})
semilogx([m.density.x(iNDirs, :);m.density.x(iNDirs, :)],[m.density.optimaly(iNDirs, :)-m.density.optimalSte(iNDirs, :); ...
                                    m.density.optimaly(iNDirs, :)+m.density.optimalSte(iNDirs, :)],'-','linewidth',2,'color',colors{iNDirs})

ylabel('Percent voxels','FontSize',16,'FontAngle','oblique')
xlabel('Fascicles per voxel','FontSize',16,'FontAngle','oblique')
legend(gca,{'Candidated','Optimized'},'box','off')
set(gca,'fontsize',16, ...
    'ylim', [0 30], ...
    'ytick',[0 15 30], ...
    'xlim', [0.5 2^10],'xtick',[0 m.density.x(iNDirs, :)],...
    'box','off','tickdir','out','ticklength',[0.025 0])
saveFig(fh,fullfile(saveDir, figName),1)
end

figName = sprintf('RMSE_mean_HistDataVSOpt_NDirs%i_%i_%i_%i_%i_%s',numDirs,  fname(1:39));
fh  = figure('name',figName,'visible',figVisible,'color','w');
for iNDirs = 1:size(m.rmse.x,1)
plot(m.rmse.x(iNDirs, :),m.rmse.data(iNDirs, :),'k-','linewidth',2,'color',[.15 .15 .15].*iNDirs)
hold on
plot(m.rmse.x(iNDirs, :),m.rmse.model(iNDirs, :),'r-','linewidth',2, 'color',colors{iNDirs})
plot([m.rmse.x(iNDirs, :);m.rmse.x(iNDirs, :)], ...
     [m.rmse.data(iNDirs, :)-m.rmse.dataSte(iNDirs, :);m.rmse.data(iNDirs, :)+m.rmse.dataSte(iNDirs, :)],'k-','linewidth',2,'color',[.1 .1 .1].*iNDirs);
plot([m.rmse.x(iNDirs, :);m.rmse.x(iNDirs, :)],[m.rmse.model(iNDirs, :)-m.rmse.modelSte(iNDirs, :);m.rmse.model(iNDirs, :)+m.rmse.modelSte(iNDirs, :)],'r-','linewidth',2, 'color',colors{iNDirs})

ylabel('Percent voxels','FontSize',16,'FontAngle','oblique')
xlabel('RMSE (raw scanner units)','FontSize',16,'FontAngle','oblique')
legend(gca,{'Data','Model'},'box','off')
set(gca,'fontsize',16, ...
    'ylim', [0 30], ...
    'ytick',[0 15 30], ...
    'xlim', [0 100],'xtick',[0 50 100],...
    'box','off','tickdir','out','ticklength',[0.025 0])
saveFig(fh,fullfile(saveDir, figName),1)
end

for iNDirs = 1:size(m.rrmse.x,1)
   
    figName = sprintf('RRMSE_ratio_HistDataVSOpt_NDirs%i_%s',numDirs(iNDirs),  fname(1:39));
    fh  = figure('name',figName,'visible',figVisible,'color','w');
    xpatch = [.5 m.rrmse.x(iNDirs,  m.rrmse.x(iNDirs, :)<=1) 1];
    ypatch = m.rrmse.y(iNDirs,  m.rrmse.x(iNDirs, :)<=1);
    proportionModelBetter = sum(ypatch);
    ypatch = [0 ypatch ypatch(end)];
    patch([xpatch,fliplr(xpatch)],[ypatch,zeros(size(ypatch)),],[.8 .8 .8])
    hold on
    plot([1 1],[0 14],'k--')
    plot(m.rrmse.x(iNDirs, :),m.rrmse.y(iNDirs, :),'k-','linewidth',2)
    plot([m.rrmse.x(iNDirs, :);m.rrmse.x(iNDirs, :)],[m.rrmse.y(iNDirs, :)-m.rrmse.ste(iNDirs, :);m.rrmse.y(iNDirs, :)+m.rrmse.ste(iNDirs, :)],'r-','linewidth',2)
    ylabel('Percent voxels','FontSize',16,'FontAngle','oblique')
    xlabel('R_{rmse}','FontSize',16,'FontAngle','oblique');
    title(sprintf('R < 1 in %2.0f%% of voxels',round(proportionModelBetter)),'FontSize',16,'FontAngle','oblique')
    set(gca,'fontsize',16, ...
        'ylim', [0 14], ...
        'ytick',[0 7 14], 'xscale', 'log', ...
        'xlim', [.5 2],'xtick',[.5 1 2],...
        'box','off','tickdir','out','ticklength',[0.025 0])
    saveFig(fh,fullfile(saveDir, figName),1)
end

figName = sprintf('NFibers_hist_NDirs%i_%i_%i_%i_%i_%s',numDirs,  fname(1:39));
fh  = figure('name',figName,'visible',figVisible,'color','w');
y = m.nfibers.y./500000;
x = m.nfibers.x;
semilogx(x,y,'ko-')
ylabel('Proportion supported fascicles','FontSize',16,'FontAngle','oblique')
xlabel('Number of diffusion directions','FontSize',16,'FontAngle','oblique')
set(gca,'fontsize',16, ...
    'xlim', [6 100],'xtick',fliplr(x),... 
    'ylim', [0.1 .2],'ytick',[0.1 0.15 .2],...
    'box','off','tickdir','out','ticklength',[0.025 0])
saveFig(fh,fullfile(saveDir, figName),1)

end  % Main function


%---------------------------------%
function saveMapSagital(fh,figName,saveDir,M,m,SD,maxfd,map)
% This helper function saves two figures for each map and eps with onlythe
% axis and a jpg with only the brain slice.
% The two can then be combined in illustrator.
%
% First we save only the slice as jpeg.
set(gca,'fontsize',16,'ytick',[-80 -40 0 40 80], ...
    'ztick',[-40  0  40  80], ...
    'xlim',[-80 80],'ylim',[-110 100],'zlim',[-60 80],'tickdir','out','ticklength',[0.025 0])
axis off
saveFig(fh,fullfile(saveDir,figName),'tiff')
saveFig(fh,fullfile(saveDir,figName),'png')

% Then we save the slice with the axis as
% eps. This will only generate the axis
% that can be then combined in illustrator.
axis on
grid off

title(sprintf('mean %2.2f | median %2.2f | SD %2.2f', ...
    M,m,SD),'fontsize',16,'FontAngle','oblique')
zlabel('Z (mm)','fontsize',16,'FontAngle','oblique')
xlabel('X (mm)','fontsize',16,'FontAngle','oblique')
cmap = colormap(eval(sprintf('%s(255)',map)));
colorbar('ytick',linspace(0,1,5),'yticklabel', ...
    {1, num2str(ceil(maxfd/8)), num2str(ceil(maxfd/4)), ...
    num2str(ceil(maxfd/2)), num2str(ceil(maxfd))}, ...
    'tickdir','out','ticklength',[0.025 0],'fontsize',16)
saveFig(fh,fullfile(saveDir,figName),1)
end

%---------------------------------%
function saveMapCoronal(fh,figName,saveDir,M,m,SD,maxfd,map)
% This helper function saves two figures for each map and eps with onlythe
% axis and a jpg with only the brain slice.
% The two can then be combined in illustrator.
%
% First we save only the slice as jpeg.
set(gca,'fontsize',16,'ztick',[-20 -10 0 10 20], ...
    'xtick',[0 10 20 30 40 50], ...
    'xlim',[-5 70],'zlim',[-30 40],'tickdir','out','ticklength',[0.025 0])
axis off
saveFig(fh,fullfile(saveDir, figName),'tiff')
saveFig(fh,fullfile(saveDir, figName),'png')

% Then we save the slice with the axis as
% eps. This will only generate the axis
% that can be then combined in illustrator.
axis on
grid off

title(sprintf('mean %2.2f | median %2.2f | SD %2.2f', ...
    M,m,SD),'fontsize',16,'FontAngle','oblique')
zlabel('Z (mm)','fontsize',16,'FontAngle','oblique')
xlabel('X (mm)','fontsize',16,'FontAngle','oblique')
cmap = colormap(eval(sprintf('%s(255)',map)));
colorbar('ytick',linspace(0,1,5),'yticklabel', ...
    {1, num2str(ceil(maxfd/8)), num2str(ceil(maxfd/4)), ...
    num2str(ceil(maxfd/2)), num2str(ceil(maxfd))}, ...
    'tickdir','out','ticklength',[0.025 0],'fontsize',16)
saveFig(fh,fullfile(saveDir, figName),1)
end

%-------------------------------%
function saveFig(h,figName,eps)
if ~exist( fileparts(figName), 'dir'), mkdir(fileparts(figName));end
fprintf('[%s] saving figure... \n%s\n',mfilename,figName);

switch eps
    case {0,'jpeg'}
        eval(sprintf('print(%s, ''-djpeg90'', ''-opengl'', ''%s'')', num2str(h),[figName,'.jpg']));
    case {1,'eps'}
        eval(sprintf('print(%s, ''-cmyk'', ''-painters'',''-depsc2'',''-tiff'',''-r500'' , ''-noui'', ''%s'')', num2str(h),[figName,'.eps']));
    case 'png'
        eval(sprintf('print(%s, ''-dpng'',''-r500'', ''%s'')', num2str(h),[figName,'.png']));
    case 'tiff'
        eval(sprintf('print(%s, ''-dtiff'',''-r500'', ''%s'')', num2str(h),[figName,'.tif']));
    case 'bmp'
        eval(sprintf('print(%s, ''-dbmp256'',''-r500'', ''%s'')', num2str(h),[figName,'.bmp']));
    otherwise
end

end