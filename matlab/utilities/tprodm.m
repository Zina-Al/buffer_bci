function [Z]=tprodm(X,xdimspec,Y,ydimspec,varargin)
% Multi-dimensional generalisation of matrix multiplication -- matlab based
%
% function [Z]=tprod(X,xdimspec,Y,ydimspec[,optStr,blksz])
%
% N.B. Fallback raw matlab based implement of the tprod-mex code.  This version 
% is generally slower and more memory intensive and is provided as a fallback method if
% the compilied version of tprod is not available.
% 
% This function computes a generalised multi-dimensional matrix product
% based upon the Einstein Summation Convention (ESC).  This means
% given 2 n-d inputs:
%   X = [ A x B x C x E .... ], denoted in ESC as X_{abce}
%   Y = [ D x F x G x H .... ], denoted in ESC as Y_{dfgh}
% we define a particular tensor operation producing the result Z as
%  Z_{cedf} = X_{abce}Y_{dfab}
% where, we form an inner-product (multiply+sum) for the dimensions with
% *matching* labels on the Right Hand Side (RHS) and an outer-product over
% the remaining dimensions.  Note, that in conventional ESC the *order* of
% dimensions in Z is specified on the LHS where the matching label specifies
% its location.
% 
% Tprod calls closely follow this convention, the tprod equivalent of the
% above is[1]:
%  Z = tprod(X,[-1 -2 1 2],Y,[3 4 -1 -2])
% here, *matching negatively* labelled RHS dimensions are inner-product
% dimensionss, whilst the *positively* labelled dimensions directly
% specify the position of that dimension in the result Z. Hence only 2
% dimension-specifications are needed to unambigiously specify this
% tensor product.  
%
% [1] Note: if you find this syntax to difficult the ETPROD wrapper function
% is provided to directly make calls in ESC syntax, e.g.
%    Z = etprod('cedf',X,'abce',Y,'dfab');
%
% It is perhaps easiest to understand the calling syntax with some examples: 
%
% 1-d cases
%   X = randn(100,1);             % make 100 1-d data points
%   Z = tprod(X,1,X,1);           % element-wise multiply, =X.*X
%   Z = tprod(X,1,X,2);           % outer-product = X*X'
%   Z = tprod(X,-1,X,-1);         % inner product = X'*X
%
% 2-d statistical examples
%   X=randn(10,100);              % 10d points x 100 trials
%   Z=tprod(X,[-1 2],X,[-1 2]);   % squared norm of each trial, =sum(X.*X)
%   Z=tprod(X,[1 -2],X,[2 -2]);   % covariance over trials,     =X*X'
%
% More complex 3-d cases
%   X = randn(10,20,100);          % dim x samples x trials set of timeseries
%   sf= randn(10,1);               % dim x 1 spatial filter
%   tf= randn(20,1);               % samples x 1 temporal filter
%
%   % spatially filter Z -> [1 x samp x trials ]
%   Z=tprod(X,[-1 2 3],sf,[-1 1]);
%   % MATLAB equivalent: reshape(reshape(X,[10,20*100])*sf,[1 20 100])
%
%   % temporaly fitler Z -> [dim x 1 x trials ]
%   Z=tprod(X,[1 -2 3],tf,[-2 2]); 
%   % MATLAB equivalent: for i=1:size(X,3); Z(:,:,i)=X(:,:,i)*tf; end;
%   
%   % OP over dim, IP over samples, sequ over trial = per trial covariance
%   Z=tprod(X,[1 -2 3],X,[2 -2 3])/size(X,3); 
%   % MATLAB equivalent: for i=1:size(X,3); Z(:,:,i)=X(:,:,i)*X(:,:,i)'./size(X,3); end;
%
% n-d cases
%
%  X = randn(10,9,8,7,6);
%  Z = tprod(X,[1 2 -3 -4 3],X,[1 2 -3 -4 3]); % accumulate away dimensions 3&4 and squeeze the result to 3d
%  % MATLAB equivalent; for i=1:size(X,5); Xi=reshape(X(:,:,:,:,i),[10*9 8*7]); Z(:,:,i) = reshape(sum(Xi.*Xi,2),[10 9]); end;
%
% INPUTS:
%  X        - n-d double/single matrix
%
%  xdimspec - signed label for each X dimension. Interperted as:
%              1) 0 labels must come from singlenton dims and means they are
%              squeezed out of the input.
%              2) NEGATIVE labels must come in matched pairs in both X and Y 
%                 and denote inner-product dimensions
%              3) POSITIVE labels denote the position of this dimension in
%              the output matrix Z.  Positive labels must be unique in X.
%              Depending on whether the same label occurs in Y 2 conditions
%              can occur:
%                a) X label has NO match in Y.  Then this is an
%                outer-product dimension.  
%                b) X label matches a label in Y. Then this dimension is an
%                aligned in both X and Y, such that they increment together
%                -- as if there was an outer loop over these dims indicies
%
%  Y        - m-d double/single matrix, 
%             N.B. if Y==[], then it is assumed to be a copy of X.
%
%  ydimspec - signed label for each Y dimension.  If not given yaccdim
%             defaults to -(1:# negative labels in (xdimspec)) followed by
%             enough positive lables to put the remaining dims after the X
%             dims in the output. (so it accumlates the first dims and
%             outer-prods the rest)
%
%  optStr  - String of single character control options,
%            'm'= don't use the, fast but perhaps not memory efficient,
%                 MATLAB code when possible. 
%  blksz    - Internally tprod computes the results in blocks of blksz size in 
%             order to keep information efficiently in the cache.  TPROD 
%             defaults this size to a size of 16, i.e. 16x16 blocks of doubles.
%             On different machines (with different cache sizes) tweaking this
%             parameter may result some speedups.
% 
% OUTPUT:
%  Z       - n-d double matrix with the size given by the sizes of the
%            POSITIVE labels in xdimspec/ydimspec
%
% See Also:  tprod_testcases, etprod
%
% Class support of input:
%     float: double, single
% 
% 
% Copyright 2006-     by Jason D.R. Farquhar (jdrf@zepler.org)

if ( nargin<4 )
  error('Insufficient arguments');
end
if ( isempty(ydimspec) ) ydimspec=xdimspec; end;
if ( isempty(Y) ) Y=X; end;

% process the dim-spec to identify the bits we need.
szX=size(X); szX(end+1:numel(xdimspec))=1;
ipIdxX = find(xdimspec<0); % IP dims
opIdxX = find(xdimspec>0); % OP dims
mIdxX  = []; % matched OP dims
szY=size(Y); szY(end+1:numel(ydimspec))=1;
opIdxY = find(ydimspec>0); % OP dims
mIdxY  = []; % matched dims
% matching negative indices/IP dims, in same order as in Xdimspec
tmp = find(ydimspec<0); % IP dims
ipIdxY=zeros(size(tmp));
for d=1:numel(ipIdxX);
  m = find(xdimspec(ipIdxX(d))==ydimspec(tmp));
  ipIdxY(d) = tmp(m);
end;
% matching positive indices/OP dims
matchX= false(size(opIdxX)); matchY=false(size(opIdxY));
for d=1:numel(opIdxY);
  m = find(xdimspec(opIdxX)==ydimspec(opIdxY(d)));
  if( ~isempty(m) ) 
    mIdxX = [mIdxX; opIdxX(m)]; matchX(m)=true;
    mIdxY = [mIdxY; opIdxY(d)]; matchY(d)=true;
  end;
end;
% remove from op dim sets
opIdxX(matchX)=[]; opIdxY(matchY)=[];

% convert from n-d to 3-d matrices
% X
% permute so dim order is: [OP IP Match]
% N.B. permute uses [order] where order(i) = oldDimension number moved to i'th new dimension
xperm = [opIdxX(:); ipIdxX(:); mIdxX(:)];
tmp = true(1,max(2,max(xperm))); tmp(xperm)=false; % find unused dims
xperm = [xperm(:)' find(tmp)]; % make a valid permutation, by adding unused
X=permute(X,xperm); 
% now reshape to be 3d
X=reshape(X,[prod(szX(opIdxX)) prod(szX(ipIdxX)) prod(szX(mIdxX))]);

% Y
% permute to be: [IP OP Match]
yperm = [ipIdxY(:); opIdxY(:); mIdxY(:)];
tmp = true(1,max(2,max(yperm))); tmp(yperm)=false; % find unused dims
yperm = [yperm(:)' find(tmp)]; % make a valid permutation by adding unused dims
Y=permute(Y,yperm); 
% now reshape to be 2d
Y=reshape(Y,[prod(szY(ipIdxY)) prod(szY(opIdxY)) prod(szY(mIdxY))]);

% compute the output
Z=zeros(size(X,1),size(Y,2),size(X,3),class(X));
for mi=1:size(X,3);
  Z(:,:,mi) = double(X(:,:,mi))*double(Y(:,:,mi));
end

% make to the desired output size
% reshape
Z=reshape(Z,[szX(opIdxX) szY(opIdxY) szX(mIdxX) 1 1]);
% permute
zperm = [xdimspec(opIdxX) ydimspec(opIdxY) xdimspec(mIdxX)];
% invert to be the order permute expects
zpermi=zeros(max(zperm),1); for i=1:numel(zperm); zpermi(zperm(i))=i; end;
zpermi(zpermi==0)=numel(zperm)+(1:sum(zpermi==0));
% permute to desired output shape
Z=permute(Z,[zpermi; numel(zpermi)+(1:(ndims(Z)-numel(zpermi)))]);
return;



%------------------------------------------
% Below is some code to test the correctness of this version
function []=testCases()
sz=21;
% test dim order processing
X=randn(sz,sz+1,sz+2); Y=randn(size(X,1),size(X,3));
% leading dim
tic,Z=tprod(X,[-1 2 3],Y,[-1 1]);t=toc;
tic,Zm=tprodm(X,[-1 2 3],Y,[-1 1]);tm=toc;
fprintf('err=%g,mex=%g mat=%g\n',mad(Z,Zm),t,tm)
% trailing dim
tic,Z=tprod(X,[2 3 -1],Y,[1 -1]);t=toc;
tic,Zm=tprodm(X,[2 3 -1],Y,[1 -1]);tm=toc;
fprintf('err=%g,mex=%g mat=%g\n',mad(Z,Zm),t,tm)
% test dim order processing
Y=randn(sz,size(X,2));
% middle dim
tic,Z=tprod(X,[2 -1 3],Y,[1 -1]);t=toc;
tic,Zm=tprodm(X,[2 -1 3],Y,[1 -1]);tm=toc;
fprintf('err=%g,mex=%g mat=%g\n',mad(Z,Zm),t,tm)
% multiple dims
tic,Z=tprod(X,[-1 -2 2],Y,[-1 -2]);t=toc;
tic,Zm=tprodm(X,[-1 -2 2],Y,[-1 -2]);tm=toc;
fprintf('err=%g,mex=%g mat=%g\n',mad(Z,Zm),t,tm)
% repeated positive idxs
tic,Z=tprod(X,[2 -1 -2],[],[2 -1 -2]);t=toc;
tic,Zm=tprodm(X,[2 -1 -2],[],[2 -1 -2]);tm=toc;
fprintf('err=%g,mex=%g mat=%g\n',mad(Z,Zm),t,tm)
