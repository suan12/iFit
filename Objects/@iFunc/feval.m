function [signal, ax, name] = feval(model, p, varargin)
% [signal, axes] = feval(model, parameters, axes, ...) evaluate a function
%
%   @iFunc/feval applies the function 'model' using the specified parameters and axes
%     and function parameters 'pars' with optional additional parameters.
%
%   parameters = feval(model, 'guess', x,y, ..., signal...)
%     makes a quick parameter guess. This requires to specify the signal
%     to guess from to be passed after the axes.
%   parameters = feval(model, parameters, x,y, ..., signal...)
%     requires some of the initial parameters to be given as NaN's. These
%     values are then replaced by the guessed ones.
%
% input:  model: model function (iFunc, single or array)
%         parameters: model parameters (vector, cell or vectors) or 'guess'
%         ...: additional parameters may be passed, which are then forwarded to the model
% output: signal: result of the evaluation (vector/matrix/cell)
%         axes:   returns the axes used for evaluation (cell of vector/matrix)
%
% ex:     b=feval(gauss,[1 2 3 4]); feval(gauss*lorz, [1 2 3 4, 5 6 7 8]);
%           feval(gauss,'guess', -5:5, -abs(-5:5))
%
% Version: $Revision: 1.3 $
% See also iFunc, iFunc/fit, iFunc/plot

% handle input iFunc arrays

if numel(model) > 1
  signal = {}; ax={}; name={};
  for index=1:numel(model)
    [signal{end+1}, ax{end+1}, name{end+1}] = feval(model(index), p, varargin{:});
  end
  if numel(signal) == 1, 
    signal=signal{1}; ax=ax{1};
  end
  signal = reshape(signal, size(model));
  ax     = reshape(ax, size(model));
  name   = reshape(name, size(model));
  return
end

% handle input parameter 'p' ===================================================

if nargin < 2
  p = '';
end

if isa(p, 'iData')
  varargin = { p varargin{:} };
  p = '';
end

if iscell(p) && ~isempty(p) % as model cell (iterative function evaluation)
  signal = {}; ax={}; name={};
  for index=1:numel(model)
    [signal{end+1}, ax{end+1}, name{end+1}] = feval(model, p{index}, varargin{:});
  end
  if numel(signal) == 1, 
    signal=signal{1}; ax=ax{1}; name=name{1};
  end
  return
end

if strcmp(p, 'plot')
  signal=plot(model);
  return
elseif strcmp(p, 'identify')
  signal=model;
  return
end

% handle varargin ==============================================================
% handle case where varargin contains itself model cell as 1st arg for axes and
% Signal
if ~isempty(varargin) 
  this = varargin{1};
  if iscell(this)
    Axes = this;
    if length(Axes) > model.Dimension
      Signal = Axes{model.Dimension+1};
      Axes   = Axes(1:model.Dimension);
    end
    if ~isempty(Signal), Axes{end+1} = Signal; end
    varargin=[ Axes{:} varargin(2:end) ];
  elseif (isstruct(this) && isfield(this, 'Axes')) || isa(this, 'iData')
    Signal = {};
    if isfield(this,'Signal')  
      Signal  = this.Signal;
      if isfield(this,'Monitor') 
        Signal  = bsxfun(@rdivide,Signal, this.Monitor); 
      end
    end

    if isa(this, 'iData')
      Axes=cell(1,ndims(this));
      for index=1:ndims(this)
        Axes{index} = getaxis(this, index);
      end
    elseif isfield(this,'Axes')    Axes    = this.Axes; 
    end
    if ~isempty(Signal), Axes{end+1} = Signal; end
    varargin= [ Axes{:} varargin(2:end) ];
  end
  clear this Axes Signal
end

ax=[]; name=model.Name;

% guess parameters ========================================================
% when p=[]='guess' we guess them all
if isempty(p)
  p = NaN*ones(size(model.Parameters));
end

% when there are NaN values in parameter values, we replace them by guessed values
if (any(isnan(p)) && length(p) == length(model.Parameters)) || strcmpi(p, 'guess')
  % call private method to guess parameters from axes, signal and parameter names
  
  % args={x,y,z, ... signal}
  args=cell(1,model.Dimension+1); args(1:end) = { [] };
  args(1:min(length(varargin),model.Dimension+1)) = varargin(1:min(length(varargin),model.Dimension+1));
  args_opt = varargin((model.Dimension+2):end);
  
  p0 = p; % save initial 'p' values
  
  % all args are empty, we generate model fake 1D/2D axes/signal
  if model.Dimension <= 2 && all(cellfun('isempty',args))
    if model.Dimension == 1
      args{1} = linspace(-5,5,50); 
      x=args{1}; p2 = [1 mean(x) std(x)/2 .1]; 
      args{2} = p2(1)*exp(-0.5*((x-p2(2))/p2(3)).^2)+((p2(2)-x)*p2(1)/p2(3)/100) + p2(4);
      clear p2
      signal = args{2};
    else
      [args{1},args{2}] = ndgrid(linspace(-5,5,50), linspace(-3,7,60));
      x=args{1}; y=args{2}; p2 = [ 1 mean(x(:)) mean(y(:)) std(x(:)) std(y(:)) 30 0 ];
      x0=p2(2); y0=p2(3); sx=p2(4); sy=p2(5);
      theta = p2(6)*pi/180;  % deg -> rad
      aa = cos(theta)^2/2/sx/sx + sin(theta)^2/2/sy/sy;
      bb =-sin(2*theta)/4/sx/sx + sin(2*theta)/4/sy/sy;
      cc = sin(theta)^2/2/sx/sx + cos(theta)^2/2/sy/sy;
      args{3} = p2(1)*exp(-(aa*(x-x0).^2+2*bb*(x-x0).*(y-y0)+cc*(y-y0).^2)) + p2(7);
      clear aa bb cc theta x0 y0 sx sy p2
      signal = args{3};
    end
  end
  
  varargin = [ args args_opt ];
  clear args
  
  % convert axes to nD arrays for operations to take place
  % check the axes and possibly use ndgrid to allow nD operations in the
  % Expression/Constraint
  if model.Dimension > 1 && all(cellfun(@isvector, varargin(1:model.Dimension)))
    [varargin{1:model.Dimension}] = ndgrid(varargin{1:model.Dimension});
  end
  
  % automatic guessed parameter values -> signal
  p1 = iFunc_private_guess(varargin, model.Parameters); % call private here -> auto guess

  % check for NaN guessed values and null amplitude
  for j=find(isnan(p1) | p1 == 0)
    if any([strfind(lower(model.Parameters{j}), 'width') ...
       strfind(lower(model.Parameters{j}), 'amplitude') ...
       strfind(lower(model.Parameters{j}), 'intensity')])
      p1(j) = abs(randn)/10;
    else
      p1(j) = 0;
    end
  end

  % specific guessed values (if any) -> p2 override p1
  if ~isempty(model.Guess) && ~all(cellfun('isempty',varargin))
    try
      if isa(model.Guess, 'function_handle')
        p2 = feval(model.Guess, varargin{:}); % returns model vector
      elseif isnumeric(model.Guess)
        p2 = model.Guess;
      else
        ax = 'xyztu';
        for index=1:model.Dimension % allocate axes
          if index <= length(varargin)
            eval([ ax(index) '=varargin{' num2str(index) '};' ]);
          end
        end
        if length(varargin) > model.Dimension && ~isempty(varargin{model.Dimension+1})
          signal = varargin{model.Dimension+1};
        else
          signal = 1;
        end
        clear ax index
        try
          p = eval(model.Guess);       % returns model vector
        catch
          eval(model.Guess);       % returns model vector and redefines 'p'
        end
        p2 = p;
        p  = p0;             % restore initial value
      end
      % merge auto and possibly manually set values
      index     = ~isnan(p2);
      p1(index) = p2(index);
      clear p2
    catch
      disp([ 'Error: Could not evaluate Guess in mode ' model.Name ' ' model.Tag ]);
      disp(model.Guess);
      disp('Axes and signal:');
      disp(varargin);
      lasterr
      rethrow(lasterror)
      % we use the 'p1' auto guess values
    end
  end

  signal = p1;  % auto-guess overridden by 'Guess' definition
  % transfer the guessed values from 'signal' to the NaN ones in 'p'
  if any(isnan(p)) && ~isempty(signal)
    index = find(isnan(p)); p(index) = signal(index);
  end
  model.ParameterValues = p; % the guessed values
  
  if ~strcmpi(p0, 'guess')
    % return the signal and axes
    [signal, ax, name] = feval(model, p, varargin{1:model.Dimension});
  else
    ax=0; name=model.Name;
  end
  
  % Parameters are stored in the updated model
  if length(inputname(1))
    assignin('caller',inputname(1),model); % update in original object
  end
  return
end

% guess axes ==============================================================
% complement axes if too few are given
if length(varargin) < model.Dimension
  % not enough axes, but some may be given: we set them to 'empty' so that default axes are used further
  for index=(length(varargin)+1):model.Dimension
    varargin{index} = [];
  end
end

% default return value...
signal= [];
parameter_names = lower(model.Parameters);
% check axes and define missing ones
for index=1:model.Dimension
  % check for default axes to represent the model when parameters are given
  % test parameter names
  
  width    = NaN;
  position = NaN;
  for index_p=1:length(parameter_names)
    if  ~isempty(strfind(parameter_names{index_p}, 'width')) ...
      | ~isempty(strfind(parameter_names{index_p}, 'tau')) ...
      | ~isempty(strfind(parameter_names{index_p}, 'damping'))
      if isnan(width)
        width = abs(p(index_p)); 
        % this parameter name is removed from the search for the further axes
        parameter_names{index_p} = ''; 
      end
    elseif ~isempty(strfind(parameter_names{index_p}, 'centre')) ...
      |    ~isempty(strfind(parameter_names{index_p}, 'center')) ...
      |    ~isempty(strfind(parameter_names{index_p}, 'position'))
      if isnan(position), 
        position = p(index_p);
        % this parameter name is removed from the search for the further axes
        parameter_names{index_p} = '';
      end
    end
    if ~isnan(width) && ~isnan(position)
      if isempty(varargin{index}) || all(all(isnan(varargin{index})))
		    % axis is not set: use default axis from parameter names and values given
		    varargin{index} = linspace(position-3*width,position+3*width, 50);
		    width = NaN; position = NaN;
		    break; % go to next axis (exit index_p loop)
		  end
    end
  end
  if isempty(varargin{index})
    varargin{index} = linspace(-5,5,50);
  end
end

% convert axes to nD arrays for operations to take place
% check the axes and possibly use ndgrid to allow nD operations in the
% Expression/Constraint
if model.Dimension > 1 && all(cellfun(@isvector, varargin(1:model.Dimension)))
  [varargin{1:model.Dimension}] = ndgrid(varargin{1:model.Dimension});
end

% evaluate expression ==========================================================

% Eval contains both the Constraint and the Expression
% in case the evaluation is empty, we compute it (this should better have been done before)
if isempty(model.Eval) 
  model.Eval=char(model);
end

% assign parameters and axes for the evaluation of the expression, in case this is model char
% p already exists, we assign axes, re-assign varargin if needed
ax = 'xyztu';
for index=1:model.Dimension
  eval([ ax(index) '=varargin{' num2str(index) '};' ]);
end
if nargout > 1
  ax = varargin(1:model.Dimension);
else
  clear ax
end

% remove axes from varargin -> leaves additional optional arguments to the function
varargin(1:model.Dimension) = []; 
if isempty(varargin)
  clear varargin
end

% evaluate now...
try
  e = cellstr(model.Eval);
  e = e(~strncmp('%', e, 1)); % remove comment lines
  eval(sprintf('%s\n', e{:}));
catch
  disp([ 'Error: Could not evaluate Expression in mode ' model.Name ' ' model.Tag ]);
  disp(model)
  model.Eval
  lasterr
  error([ 'iFunc:' mfilename ], 'Failed model evaluation.');
end
p    = mat2str(p); if length(p) > 20, p=[ p(1:20) '...' ]; end
name = [ model.Name '(' p ') ' ];

