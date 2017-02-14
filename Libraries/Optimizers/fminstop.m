function val = fminstop(x, optimValues, state)
% fminstop: an OutputFcn / PlotFcns function which displays a 'STOP' button
%
% this later can be pressed during a fit to abort the current fit procedure.
%
% Other defined function to be used as OutputFcn and PlotFcns:
%   @fminplot           shows criteria and parameter space, with a STOP button
%   @optimplotx         plots the current point
%   @optimplotfval      plots the function value
%   @optimplotfunccount plots the function count
%
% example: 
%   fmin(@objective, [], 'OutputFcn=fminplot')

persistent fig stop

if nargin < 3, return; end

if isempty(stop), stop = false; end

if  stop &&  isempty(fig), stop  = false;  end  % remains from last stop event
if  stop && ~isempty(fig) && ~ishandle(fig), state = 'done'; end  % close figure 
if ~stop &&  isempty(fig) && ~strcmp(state,'done'), fig = fminstop_create; end % waiting without figure: create it.

switch state
case 'init'
  % open a figure with a single toggle button
  fig = findall(0, 'Tag','Optim:fminstop');
  if length(fig) > 1, delete(fig(2:end)); end % unique instance

  if isempty(fig) % create window
    fig = fminstop_create;
  end
  stop = false;
  
case {'iter','interrupt'}
  % return stop if the figure is closed
  if ~isempty(fig)
    if ~ishandle(fig) || ~strcmp(get(fig,'Tag'), 'Optim:fminstop') % closed by user
      stop = true;
      delete(fig);
    end
    drawnow;
  end
case 'done'
  % close window
  delete(fig);
  drawnow;
  stop = true;
  fig  = [];
end

val = stop;

% ------------------------------------------------------------------------------
function fig = fminstop_create
  fig = figure('Tag','Optim:fminstop','MenuBar','None','NextPlot','new', ...
      'Name','Fit [close to abort]','CloseRequestFcn','fminstop([],[],''done'');');
  p = get(fig, 'Position');
  p(3:4) = [100 50];
  set(fig, 'Position',p);
  h = uicontrol(fig,'String','STOP FIT',...
    'Style','pushbutton','callback','fminstop([],[],''done'');','BackgroundColor','red', ...
    'Units','normalized','Position',[.1 .1 .8 .8], ...
    'ToolTipString','Click me to abort current fit');
    
  drawnow;