function b = subsasgn(a,S,val)
% b = subsasgn(a,index,b) : iFunc indexed assignement
%
%   @iFunc/subsasgn: function defines indexed assignement 
%   such as a(1:2,3) = b
%
% Version: $Revision: 1.1 $
% See also iFunc, iFunc/subsref

% This implementation is very general, except for a few lines

b = a;  % will be refined during the index level loop

if isempty(S)
  return
end

% first handle object array for first index
if numel(b) > 1 && any(strcmp(S(1).type,{'()','{}'}))
  c = b(S(1).subs{:}); % get elements in the array
  if ~isvector(c) d = c(:); else d=c; end
  if length(d) == 1
    d = iFunc(val);
  else
    if ~isempty( S(2:end) ) % array([1 2 3]).something = something
		  for j = 1:length(d)
		    d(j) = subsasgn(d(j),S(2:end),val);
		  end
		else	% single level array assigment as array([1 2 3]) = something
			for j = 1:length(d)
				if length(val) == 1, d(j) = iFunc(val);
				elseif length(val) == length(d)
					d = iFunc(val);
				else
					error([ mfilename ': can not assign ' num2str(length(d)) ' iFunc array to ' num2str(length(val)) ' ' class(val) ' array for object ' inputname(1) ' ' b(1).Tag ]);
				end
			end
		end
  end
  if prod(size(c)) ~= 0 && prod(size(c)) == prod(size(d)) && length(c) > 1
    c = reshape(d, size(c));
  else
    c = d;
  end
  b(S(1).subs{:}) = c;
else
  % multiple level assignment: only the last subs indexing must be assigned, the previous ones must be subsref calls
  if length(S) > 1
    for i=1:(length(S)-1)
      b = subsref(b, S(i));       % navigate to the pre-last level -> b, e.g. not an iFunc
    end
    b = subsasgn(b, S(end), val); % assigment for last level
    b = subsasgn(a, S(1:(end-1)), b);
    return
  end
  
  % single level assignment
  s = S(1);
  switch s.type
  case '()'       
    if numel(b) > 1   % array() -> deal on all elements
    % SYNTAX: array(index) = val: set Data using indexes
      c = [];           
      for j = 1:length(s.subs{:})
        c = [ c subsasgn(c(j),s,val) ];
      end
      b = reshape(c, size(b));
    end                 % if single object
  case '.'
  % SYNTAX: object.field = val
    if numel(b) > 1   % object array -> deal on all elements
      c = [];
      for j = 1:length(c)
        c = [ c subsasgn(c(j),s,val) ];
      end
      b = reshape(c, size(b));
    else
    % protect some fields
      fieldname = s.subs;
      if length(fieldname) > 1 && iscellstr(fieldname)
        fieldname = fieldname{1};
      end
      f     = fieldnames(b);
      index = find(strcmpi(fieldname, fieldnames(b)));
      if ~isempty(index) % structure/class def fields: b.field
        b.(f{index}) = val;
        if strcmp(f{index},{'Expression','Constraint'})
          % check object when modifying key members
          b.Eval='';
          b=iFunc(b);
        end
      else
        error([ mfilename ': can not set iFunc object Property ''' fieldname ''' in iFunc model ' b.Tag '.' ]);
      end
    end
  end   % switch s.type
  
end

if nargout == 0 && ~isempty(inputname(1))
  assignin('caller',inputname(1),b);
end
