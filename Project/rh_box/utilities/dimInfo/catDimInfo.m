function di=catDimInfo(dim,varargin)
% Concatenate dim-info objects
%
% di=catDimInfo(dim,di1,di2,...)
%
% Inputs:
%  dim -- the dimension to cat along
%  di1, di2, ... -- the dim-info structures to cat
% Outputs:
%  di -- the concatenated di structure
di = [];
for idi=1:numel(varargin)
   if ( isempty(varargin{idi}) ) continue; end;
   cdi = varargin{idi};
   if( dim>=numel(cdi) ) 
     cdi(dim+1)=cdi(end); cdi(dim)=mkDimInfo(1,1,'new',1); 
     if ( dim<=numel(di) && iscell(di(dim).vals) ) cdi(dim).vals={''}; end;
   end;
   % add source info if needed
   if( isempty(cdi(dim).extra) ) [cdi(dim).extra(1:numel(cdi(dim).vals)).src]=deal(idi);
   elseif ( ~isfield(cdi(dim).extra,'src') ) [cdi(dim).extra.src]=deal(idi); 
   else
      osrc=[cdi(dim).extra.src]; nf=10.^(ceil(log10(max(abs(osrc)))));
      [cdi(dim).extra.src]=num2csl(idi+osrc/nf); % use fractional src id
   end

   if ( isempty(di) ) 
      di=cdi;
      continue; 
   end;
   if ( ~isstruct(cdi) || numel(cdi) ~= numel(di) ) 
      error('Not a diminfo structure of the same size');
   end
   for d=1:numel(di); % validate compatiability
      if ( ~isequal(cdi(d).name,'new') && ~isequal(cdi(d).name,di(d).name) ) 
         error('Incompatiable dimension names: %s,%s',di(d).name,cdi(d).name);
      elseif ( ~isequal(cdi(d).units,di(d).units) && ~(d==numel(di) && isempty(cdi(d).units)) ) 
         error('Incompatiable units');
      elseif ( d~=dim && ~isequal(cdi(d).vals,di(d).vals) && ~(d==numel(di) && isempty(cdi(d).vals)) ) 
         fprintf('%s: Warning: Incompatiable values for di %d=%s\n',mfilename,d,di(d).name);
      end
   end
   
   % passed the compatiability tests, do the cat
   di(dim).vals  = cat(2,di(dim).vals,cdi(dim).vals);
   fns=fieldnames(di(dim).extra); cfns=fieldnames(cdi(dim).extra);
   cfne = setdiff(cfns,fns); 
   if ( ~isempty(cfne) ) cdi(dim).extra = rmfield(cdi(dim).extra,cfne); end;
   cfne = setdiff(fns,cfns); for i=1:numel(cfne); [cdi(dim).extra.(cfne{i})]=deal([]); end;
   di(dim).extra = cat(2,di(dim).extra,cdi(dim).extra);
%    if ( isfield(cdi(dim),'info') && ~isempty(cdi(dim).info) )
%       di(dim).info.src(idi)=cdi(dim).info; % cat the info
%    end
end
return;

%-----------------------------------------------------------------------------
function testCase()

