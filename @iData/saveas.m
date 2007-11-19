function filename = saveas(a, varargin)
% f = saveas(s, ...) : save iData object into various data formats
%
%   @iData/saveas function to save data sets
%   This function save the content of iData objects. 
%
% input:  s: object or array (iData)
%         filename: name of file to save to. Extension, if missing, is appended (char)
%                   If the filename already exists, the file is overwritten.
%         format: data format to use (char)
%                 'm' saves as a flat Matlab .m file (a function which returns an iData object or structure)
%                 'mat' saves as a '.mat' binary file (save as 'save')
%                 'hdf' saves as an HDF5 data set
%
% output: f: filename used to save file(s) (char)
% ex:     b=saveas(a, 'file', 'm');
%
% See also iData, iData/load, save

if length(a) > 1
  if length(varargin) >= 1, filename_base = varargin{1}; 
  else filename_base = ''; end
  filename = cell(size(a));
  for index=1:length(a(:))
    filename{index} = saveas(a(index), varargin{:});
    if isempty(filename_base), filename_base = filename{index}; end
    if length(a(:)) > 1
      [path, name, ext] = fileparts(filename_base);
      varargin{1} = [ path name '_' num2str(index) ext ];
    end
  end
  return
end

if nargin < 2, filename = ''; else filename = varargin{1}; end
if isempty(filename), filename = a.Tag; end
if nargin < 3, format=''; else format = varargin{2}; end

% handle extensions
[path, name, ext] = fileparts(filename);
if isempty(ext) & ~isempty(format), 
  ext = [ '.' format ]; 
  filename = [ filename ext ];
elseif isempty(format) & ~isempty(ext)
  format = ext(2:end);
else format='m'; filename = [ filename '.m' ];
end

switch format
case 'm'
  str = [ 'function this=' name sprintf('\n') ...
          '% Original data: ' class(a) ' ' inputname(1) ' ' a.Tag sprintf('\n') ...
          '%' sprintf('\n') ...
          '% Matlab ' version ' m-file ' filename ' saved on ' datestr(now) ' with iData/saveas' sprintf('\n') ...
          '% To use import data, type ''' name ''' at the matlab prompt.' sprintf('\n') ...
          '% You will obtain an iData object (if you have iData installed) or a structure.' sprintf('\n') ...
          '%' sprintf('\n') ...
          iData_saveas_single('this', a) ];
  [fid, message]=fopen(filename,'w+');
  if fid == -1
    iData_private_warning(mfilename,[ 'Error opening file ' filename ' to save object ' a.Tag ]);
    return
  end
  fprintf(fid, '%s', str);
  fclose(fid);
case 'mat'
  save(filename, a);
end

% ============================================================================
% private function
function str=iData_saveas_single(this, data)
% create a string [ 'this = data;' ]

NL = sprintf('\n');
if ischar(data)
  str = [ this ' = ''' iData_saveas_validstr(data) ''';' NL ];
elseif isnumeric(data) | islogical(v)
  str = [ '% ' this ' numeric (' class(data) ') size ' mat2str(size(data)) NL ...
          this ' = ' mat2str(data(:)) ';' NL this ' = reshape(' this ', ' mat2str(size(data)) ');' NL ];
elseif isstruct(data)
  f = fieldnames(data);
  str = [ '% ' this ' (' class(data) ') length ' num2str(length(f)) NL ];
  for index=1:length(f)
    str = [ str iData_saveas_single([ this '.' f{index} ], getfield(data, f{index})) ];
  end
  str = [ str '% end of struct ' this NL ];
elseif iscellstr(data)
  str = [ '% ' this ' (' class(data) 'str) size ' mat2str(size(data)) NL ...
          this ' = { ...' NL ];
  for index=1:length(data(:))
    str = [ str '  ''' iData_saveas_validstr(data{index}) '''' ];
    if index < length(data(:)), str = [ str ', ' ]; end
    str = [ str ' ...' NL ];
  end
  str = [ str '}; ' NL ];
  str = [ str this ' = reshape(' this ',' mat2str(size(data)) ');' NL '% end of cellstr ' this NL ];
elseif iscell(data)
  str = [ '% ' this class(data) ' size ' mat2str(size(data)) NL ...
          this ' = cell(' mat2str(size(data)) ');' NL ];
  for index=1:length(data(:))
    str = [ str iData_saveas_single([ this '{' num2str(index) '}' ], data{index}) NL ];
  end
  str = [ str this ' = reshape(' this ',' mat2str(size(data)) ');' NL '% end of cell ' this NL ];
elseif isa(data, 'iData')
  str = [ '% ' this ' (' class(data) ') size ' num2str(size(data)) NL ];
  str = [ str iData_saveas_single(this, struct(data)) ];
  str = [ str 'if ~exist(''iData''), return; end' NL ];
  str = [ str this '_s=' this '; ' this ' = rmfield(' this ',' this '.Alias); ' this ' = iData(' this ');' NL ...
         'setalias(' this ', ' this '_s.Alias.Names, ' this '_s.Alias.Values, ' this '_s.Alias.Labels);' NL ... 
         'setaxis('  this ', mat2str(1:length(' this '_s.Alias.Axis)), ' this '_s.Alias.Axis);' NL ...
         '% end of iData ' this NL ];
elseif isa(data, 'function_handle')
  iData_private_warning(mfilename,  'can not save function handles. Skipping.');
else
  iData_private_warning(mfilename,[ 'can not save ' class(data) '. Skipping.' ]);
  % other object
end

function str=iData_saveas_validstr(str)
index = find(str < 32 | str > 127);
str(index) = ' ';

