function in = iData_check(in)
% iData_check: make consistency checks on iData object

if numel(in) > 1
  parfor index = 1:numel(in)
    in(index) = iData_check(in(index));
  end
  return
end

if iscell(in), in = in{1}; end

% update ModifDate
in.ModificationDate = clock;
% check type of fields
if iscellstr(in.Title)
  t = strcat(in.Title,';');
  in.Title=[ t{:} ];
end
if ~ischar(in.Title) 
  iData_private_warning(mfilename,['Title must be a char or cellstr in iData object ' in.Tag ' (' class(in.Title) '). Re-setting to empty.']);
  in.Title = '';
end
in.Title = validstr(strtrim(in.Title)); in.Title(in.Title == '%') = '';
if ~ischar(in.Tag)
  iData_private_warning(mfilename,['Tag must be a char in iData object ' in.Tag ' "' in.Title '. Re-setting to a new Tad id.' ]);
  in = iData_private_newtag(in);
end
if ~ischar(in.Source)
  iData_private_warning(mfilename,['Source must be a char in iData object ' in.Tag ' "' in.Title '. Re-setting to pwd.' ]);
  in.Source = pwd;
end
if ~iscellstr(in.Command)
  in.Command = { in.Command };
end
if ~ischar(in.Date) && ~isnumeric(in.Date)
  iData_private_warning(mfilename,['Date must be a char/vector in iData object ' in.Tag ' "' in.Title '. Re-setting to "now".' ]);
  in.Date = clock;
end
if ~ischar(in.Creator)
  iData_private_warning(mfilename,['Creator must be a char in iData object ' in.Tag ' "' in.Title '. Re-setting to "iFit/iData".' ]);
  in.Creator = version(in);
end
if ~ischar(in.User)
  iData_private_warning(mfilename,['User must be a char in iData object ' in.Tag ' "' in.Title '. Re-setting to Matlab User.']);
  in.User = 'Matlab User';
end
% check aliases
if ~isstruct(in.Alias) || numel(in.Alias) ~= 1 || ~iscell(in.Alias.Names)
  % get the default Alias structure
  z = iData;
  in.Alias = z.Alias;
end
% check if object.Data is numeric: make it a structure so that it is better organized
if isnumeric(in.Data) && ~isempty(in.Data)
  data = in.Data;
  % do we need to deserialize ?
  if isa(data, 'uint8')
    data = hlp_deserialize(data);
  end
  in.Data = [];
  in.Data.Signal = data; clear data;
end

% identify the Signal and axes when they have not yet been defined
% get all numeric fields, sort them, get the biggest
% find axes that match the Signal dimensions
% associate 'error' and 'monitor' when they exist
% define Signal label from Attributes, when exist
sz = size(in);
if ~isempty(in.Data) && (isempty(in.Alias.Values{1}) || isempty(in.Alias.Axis))
  % get numeric fields sorted in descending size order
  [fields, types, dims] = findfield(in, '', 'numeric');
  clear types
  
  if isempty(fields), 
    iData_private_warning(mfilename,['The iData object ' in.Tag ' "' in.Title '" contains no data at all ! (double/single/logical/int/uint)']);
  else
    
    fields_all = fields; dims_all=dims;
    
    % does this looks like a Signal ?
    if isempty(in.Alias.Values{1})
      
      if length(dims) > 1 % when similar sizes are encoutered, get the one which is not monotonic
        
        % list of 'biggest' fields
        maxdim=find(dims == dims(1)); maxdim2 = maxdim;
        keep_at_start = 1:length(maxdim);
        send_at_end   = [];
        % move 'error' and constant/monotonic down in the list
        for idx=1:length(maxdim)
          index=maxdim2(idx);
          x = get(in, fields{index});
          if ischar(x) || length(x) <= 1
            % this is a char or scalar: move to end of list
            send_at_end = [ send_at_end idx ];
            keep_at_start(keep_at_start == idx) = [];
            continue; 
          end
          if issorted(x(:)) ...
            || ~isempty(strfind(lower(fields{index}), 'error')) ...
            || ~isempty(strfind(lower(fields{index}), 'e')) ...
            || ~isempty(strfind(lower(fields{index}), 'monitor'))
            % this is a constant/monotonic value or 'error' or 'monitor'
            % move down in fields list
            send_at_end = [ send_at_end idx ];
            keep_at_start(keep_at_start == idx) = [];
          end
          clear x
        end
        % now reorder the fields
        maxdim2 = maxdim([ keep_at_start send_at_end ]);
        fields(maxdim) = fields(maxdim2);
      end

      % in case we have more than one choice, get the first one and error bars
      error_id = []; monitor_id=[];
      if length(dims) > 1 || iscell(fields)
        select = [];
        % do we have an 'error' which has same dimension ?
        for index=find(dims(:)' == dims(1))
          if index==1, continue; end % not the signal itself
          if ~isempty(strfind(lower(fields{index}), 'error')) || ...
              strcmpi(fields{index}, 'e')
            error_id = fields{index};
          elseif ~isempty(strfind(lower(fields{index}), 'monitor'))
            monitor_id = fields{index};
          elseif isempty(select)
            select = index;
          end
        end
        if isempty(select), select =1; end
        dims=dims(select);
        fields=fields{select};
      end

      % index: is the field and dimension index to assign the Signal
      if dims > 0
        disp([ 'iData: Setting Signal="' fields '" with length ' num2str(dims) ' in object ' in.Tag ' "' in.Title '".' ]);
        in.Alias.Values{1} = fields;
        
        % get potential attribute (in Data.Attributes fields)
        attribute = fileattrib(in, fields);
        
        if isstruct(attribute)
          attribute = class2str(' ',attribute, 'no comments');
        end
        if ischar(attribute)
          if numel(attribute) > 80, attribute=[ attribute(1:77) ' ...' ]; end
          in.Alias.Labels{1} = validstr(attribute);
        end

        % assign potential 'error' bars and 'monitor'
        if ~isempty(error_id) && ~strcmp(monitor_id,'Error')
          in.Alias.Values{2} = error_id;
        end
        if ~isempty(monitor_id) && ~strcmp(monitor_id,'Monitor')
          in.Alias.Values{3} = monitor_id;
        end
      end
    end % if no Signal
   
    % look for vectors that may have the proper length as axes
    sz = size(in);
    myisvector = @(c)length(c) == numel(c);
    for index=1:ndims(in)
      if length(in.Alias.Axis) < index || isempty(in.Alias.Axis{index})

        % search for a vector of length size(in, index)
        ax = find(dims_all == sz(index));   % length of dim, or length(dim)+1
        if isempty(ax), ax = find(dims_all == sz(index)+1); end
        if length(ax) > 1; ax=ax(1); end
        if ~isempty(ax) && (~ischar(in.Alias.Values{1}) || ~strcmp(fields_all{ax},in.Alias.Values{1}) )
          val = get(in, fields_all{ax});
          if ischar(val)  % this is already a link/alias
            in = setaxis(in, index, val);
          elseif myisvector(val) && issorted(val(:))
            if length(val) == size(in, index) && min(val(:)) < max(val(:))
              % n bins
              val = fields_all{ax};
            elseif length(val) == size(in, index)+1 && min(val(:)) < max(val(:))
              % there are n+1 poles for n bins
              val = (val(1:(end-1)) + val(2:end))/2;
            else val = [];
            end
            if ~isempty(val)  % the axis could be found
              in = setaxis(in, index, [ 'Axis_' num2str(index) ], val);
              % search if there is a corresponding label (in Attributes)
            end
          end
          % assign a Label to the axis
          if isfield(in.Data, 'Attributes')
            fields=fliplr(strtok(fliplr(fields_all{ax}), '.')); % last word in alias
            if isfield(in.Data.Attributes, fields) && ischar(in.Data.Attributes.(fields))
              in.Alias.Labels{index+1} = validstr(in.Data.Attributes.(fields));
            end
          else
            label(in, index, fields_all{ax});
          end
          disp([ 'iData: Setting Axis{' num2str(index) '} ="' fields_all{ax} '" with length ' num2str(sz(index)) ' in object ' in.Tag ' "' in.Title '".' ]);
          clear val
        else
          break; % all previous axes must be defined. If one misses, we end the search
        end
      end % this axis not defined
    end % for
  end % has fields
else
  % check aliases (valid ?) by calling setalias(in)
  in = setalias(in);

  % check axis (valid ?) by calling setaxis(in)
  in = setaxis(in);
end % if no Signal defined

sz = size(in);
% check the axes orientations
% for all axes, determine when possible their preferred rank by looking at their dimension
if ndims(in)>=2 && ~isvector(in)
  for index=1:ndims(in)
    % when axis is vector: its length should match some of the signal dimension
    x  = getaxis(in, index);  % axis value
    lx = numel(x);
    % find numel(axis) == size(in):  true for vectors matching a signal rank
    ix = find(lx == sz);
    if length(ix)==1 && ix ~= index
      % axis 'index' should be going into rank 'ix': we swap axes
      x1 = getaxis(in, num2str(index));
      x2 = getaxis(in, num2str(ix));
      setaxis(in, ix,    x1);
      setaxis(in, index, x2);
      clear x1 x2
    end
  end
end


function str=validstr(str)
  % validate a string as a single line
  str=strrep(str(:)', sprintf('\n'), ';');
  index = find(str < 32 | str > 127);
  str(index) = ' ';
  str=strrep(str, '''', '''''');
  str=strrep(str,'\','/');
  if isempty(str), str=''; end
