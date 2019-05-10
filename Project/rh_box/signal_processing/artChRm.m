function [X,info]=artChRm(X,dim,idx,varargin);
% remove any signal correlated with the input signals from the data
% 
%   [X,info]=artChRm(X,dim,idx,varargin)
%
% Inputs:
%  X   -- [n-d] the data to be deflated/art channel removed
%  dim -- dim(1) = the dimension along which to correlate/deflate ([1 2])
%         dim(2) = the time dimension for spectral filtering/detrending along
%  idx -- the index/indicies along dim(1) to use as artifact channels ([])
% Options:
%  bands   -- spectral filter (as for fftfilter) to apply to the artifact signal ([])
%  fs  -- the sampling rate of this data for the time dimension ([])
%         N.B. fs is only needed if you are using a spectral filter, i.e. bands.
%  detrend -- detrend the artifact before removal                        (1)
%  center  -- center in time (0-mean) the artifact signal before removal (0)
opts=struct('detrend',1,'center',0,'bands',[],'fs',[],'maxIter',0,'tol',1e-2,'verb',0);
[opts]=parseOpts(opts,varargin);


dim(dim<0)=ndims(X)+1+dim(dim<0);
if ( numel(dim)>2 ) error('Multiple dim not implementated yet!'); end;

% compute the artifact signal and its forward propogation to the other channels
if ( ~isempty(opts.bands) ) % smoothing filter applied to art-sig before we use it
  artFilt = mkFilter(floor(size(X,dim(end))./2),opts.bands,opts.fs/size(X,dim(end)));
else
  artFilt=[];
end

% make a index expression to extract the artifact channels
artIdx=cell(ndims(X),1); for d=1:ndims(X); artIdx{d}=1:size(X,d); end; artIdx{dim(1)}=idx;
% Iteratively refine the artifact signal by propogating to the rest of the electrodes and back again
tpIdx  = [-(1:dim(1)-1) 1 -(dim(1)+1:ndims(X))];
tpIdx2 = [-(1:dim(1)-1) 2 -(dim(1)+1:ndims(X))];
sf=[];
for iter=0:opts.maxIter;
   if ( iter==0 ) % extract artifact signal from the data
      artSig = X(artIdx{:});
   else % compute updated artifact signal, as weighted average of the rest
      sf=repop(sf,'./',sqrt(sum(sf.*sf)));
      artSig = tprod(X,[1:dim(1)-1 -dim(1) dim(1)+1:ndims(X)],sf,[-dim(1) dim(1)]); 
   end
   if ( opts.center )       artSig = repop(artSig,'-',mean(artSig,dim(end))); end;
   if ( opts.detrend )      artSig = detrend(artSig,dim(end)); end;
   if ( ~isempty(artFilt) ) artSig = fftfilter(artSig,artFilt,[],dim(end),1); end % smooth the result
  artCov = tprod(artSig,tpIdx,[],tpIdx2); % cov of the artifact signal: [nArt x nArt]
  if ( numel(artCov)>1 ) % whiten artifact signal
     [U,S]    = eig(artCov); S=diag(S); oS=S;
     si = S>=max(abs(S))*opts.tol; S=S(si); U=U(:,si); % remove degenerate parts
     artSig   = tprod(artSig,[1:dim(1)-1 -dim(1) dim(1)+1:ndims(X)],repop(U,'./',sqrt(abs(S))'),[-dim(1) dim(1)]); % whiten
  else % normalise artifact signal
     artSig   = artSig./sqrt(abs(artCov)); % repop(artSig,'./',shiftdim(sqrt(abs(diag(artCov))),-dim(1)+1));
  end
  sf=tprod(X,tpIdx,artSig,tpIdx2);  % [nCh x nArt]
end

% Now, finally that we've got a good estimate for the artifact signal we remove it from the data
X = X - tprod(sf,[dim(1) -dim(1)],artSig,[1:dim(1)-1 -dim(1) dim(1)+1:ndims(X)]);

info = struct('artSig',artSig,'artFilt',artFilt,'sf',sf,'artCov',artCov,'Xidx',{idx});
return;
%--------------------------------------------------------------------------
function testCase()
z=jf_mksfToy();
d=jf_deflate(z,'dim','time','mx',shiftdim(z.X(2,:,1)));
clf;image3ddi(d.X(:,:,1),d.di,1,'disptype','mcplot','legend','ne');clickplots

d2=jf_artChRm(z,'vals',2)

d=jf_deflate(z,'dim',{'time','epoch'},'mx',shiftdim(z.X(2,:,:)));
clf;image3ddi(d.X(:,:,1),d.di,1,'disptype','mcplot','legend','ne');clickplots

d=jf_deflate(z,'dim',{'time','epoch'},'mx',permute(z.X(1:2,:,:),[2 3 1]));
clf;image3ddi(d.X(:,:,1),d.di,1,'disptype','mcplot','legend','ne');clickplots

di=z.di; di(1).name='def_dir';
d=jf_deflate(z,'dim',{'time','epoch'},'mx',z.X([1:2],:,:),'di',di);
clf;image3ddi(d.X(:,:,1),d.di,1,'disptype','mcplot','legend','ne');clickplots


% test
% plot artifact channel before removal
clf;for i=1:10:size(z.X,n2d(z,'epoch')); clf;jf_plot(jf_reref(jf_retain(jf_retain(z,'dim','ch','vals','%EOG*%'),'dim','epoch','idx',i+(0:9)),'dim','time'),'disptype','plot');waitkey; end
% plot data before removal
clf;for i=1:10:size(z.X,n2d(z,'epoch')); clf;jf_plot(jf_retain(z,'dim','epoch','idx',i+(0:9)),'disptype','plot');waitkey; end

a=jf_artChRm(z,'dim','ch','vals','%EOG*%','bands',[.1 .5 6 8]);
% plot artSig used to decorrelate
clf;for i=1:10:size(z.X,n2d(z,'epoch')); clf;image3d(a.prep(end).info.artSig(:,:,i+(0:9)),1,'Yvals',a.di(2).vals,'disptype','plot');waitkey; end
% plot left over signal in the artifact channels
clf;for i=1:10:size(z.X,n2d(z,'epoch')); clf;jf_plot(jf_reref(jf_retain(jf_retain(a,'dim','ch','vals','%EOG*%'),'dim','epoch','idx',i+(0:9)),'dim','time'),'disptype','plot');waitkey; end
% plot data after removal
clf;for i=1:10:size(z.X,n2d(z,'epoch')); clf;jf_plot(jf_retain(a,'dim','epoch','idx',i+(0:9)),'disptype','plot');waitkey; end

