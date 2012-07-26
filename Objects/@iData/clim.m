function a = clim(a, lims)
% b = clim(s,[ cmin cmax ]) : Reduce iData C axis limits
%
%   @iData/clim function to reduce the C axis (rank 4) limits
%     clim(s) returns the current C axis limits. 
%     Undefined axis returns [NaN NaN] as limits.
%
% input:  s: object or array (iData)
%         limits: new axis limits (vector)
% output: b: object or array (iData)
% ex:     b=clim(a);
%
% Version: $Revision: 1.7 $
% See also iData, iData/plot, iData/ylabel

% handle input iData arrays
if nargin == 1, lims = ''; end
if numel(a) > 1
  s = [];
  for index=1:numel(a)
    s = [ s ; feval(mfilename, a(index), lims) ];
  end
  if ~isempty(lims)
    a = reshape(s, size(a));
  else
    a = s;
  end
  if nargout == 0 & nargin == 2 & ~isempty(inputname(1))
    assignin('caller',inputname(1),a);
  end
  return
end

axisvalues = getaxis(a, 4);
if isempty(axisvalues), a=[nan nan]; return; end
if isempty(lims)
  a=[ min(axisvalues) max(axisvalues) ];
  return
end

index=find(lims(1) <= axisvalues & axisvalues <= lims(2));
s.type='()';
s.subs={ ':', ':', ':', index };
cmd=a.Command;
a = subsref(a,s);
a.Command=cmd;
a=iData_private_history(a, mfilename, a, lims);

if nargout == 0 & length(inputname(1))
  assignin('caller',inputname(1),a);
end