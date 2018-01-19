function [s, sphi] = dynamic_range(s, Ei, angles)
% iData_Sqw2D: dynamic_range: crop the S(|q|,w) to the available dynamic range
%   for given incident neutron energy.
%
% The dynamic range is defined from the momentum and energy conservation laws:
%  Ef         = Ei - w                                is positive
%  cos(theta) = (Ki.^2 + Kf.^2 - q.^2) ./ (2*Ki.*Kf)  is within [-1:1]
%
% The incident neutron energy can be computed using:
%  Ei = 2.0721*Ki^2 = 81.8042/lambda^2 with Ki in [Angs-1] and lambda in [Angs]
%
% conventions:
% omega = Ei-Ef = energy lost by the neutron
%    omega > 0, neutron looses energy, can not be higher than Ei (Stokes)
%    omega < 0, neutron gains energy, anti-Stokes
%
% The scattering angle phi can be restricted to match a detection area
% with the syntax:
%   sqw_Ei=dynamic_range(s, Ei, [angles])
%
% The syntax:
%   [sqw_Ei, sphiw] = dynamic_range(s,...)
% also returns the S(phi,w) data set, which shows the detected signal vs scattering 
% angle and energy transfer. This is the double differential cross section 
% as a function of the scattering angle.
%
% syntax:
%   sqw_Ei        =dynamic_range(s, Ei)
%   [sqw_Ei,sphiw]=dynamic_range(s, Ei)
%   [sqw_Ei,sphiw]=dynamic_range(s, Ei, [min_angle max_angle])
%
% input:
%   s:      Sqw data set, e.g. 2D data set with w as 1st axis (rows, meV), q as 2nd axis (Angs-1).
%   Ei:     incoming neutron energy [meV]
%   angles: scattering detection range in [deg] as a vector. Min and Max values are used.
% output:
%   sqw_Ei: S(q,w)   cropped to dynamic range for incident energy Ei.
%   sphiw:  S(phi,w) angular dynamic structure factor for incident energy Ei.
%
% Example: s=iData_Sqw2D('SQW_coh_lGe.nc'); dynamic_range(symmetrize(s), 14.8, [-20 135])
%
% See also: iData_Sqw2D/Bosify, iData_Sqw2D/deBosify, iData_Sqw2D/symmetrize, iData_Sqw2D/scattering_cross_section
% (c) E.Farhi, ILL. License: EUPL.

  % first look at the given arguments
  if nargin < 2
    Ei = [];
  end
  if nargin < 3
    angles = [];
  end

  sqw = [];

  % handle array of objects
  if numel(s) > 1
    for index=1:numel(s)
      sqw = [ sqw feval(mfilename, s(index), Ei, angles) ];
      s(index)=iData_Sqw2D; % clear memory
    end
    s = sqw;
    return
  end
  
  % check if the energy range is limited
  w = getaxis(s,1);
  if all(w(:) >= 0) || all(w(:) <= 0)
    disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ])
    disp([ '    seems to have its energy range w=[' num2str([ min(w(:)) max(w(:)) ]) '] defined only on one side.' ])
    disp('    Perhaps you should apply symmetrize and Bosify first ?');
  end
  
  % compute Ei, Ef, Ki, Kf
  % constants
  SE2V = 437.393377;        % Convert sqrt(E)[meV] to v[m/s]
  V2K  = 1.58825361e-3;     % Convert v[m/s] to k[1/AA]
  K2V  = 1/V2K;
  VS2E = 5.22703725e-6;     % Convert (v[m/s])**2 to E[meV]
  
  % search in the data set in case missing properties are stored there
  % compute Ki with given arguments
  if ~isempty(Ei)
    Ki = SE2V*V2K*sqrt(Ei);
  else
    Ki = Sqw_getT(s, {'wavevector','momentum','IncidentWavevector','Ki'});
    if isempty(Ki) || Ki==0
      lambda = Sqw_getT(s, {'wavelength','lambda'});
      if ~isempty(lambda) && lambda>0
        Ki = 2*pi/lambda;
      else
        Ei = Sqw_getT(s, {'IncidentEnergy','Ei'});
        if isempty(Ei) || Ei<=0
          w  = getaxis(s, 1);
          Ei = max(abs(w(:)));
          disp([ mfilename ': using Ei=' num2str(Ei) ' [meV] incident neutron energy.' ]);
        end
        Ki = SE2V*V2K*sqrt(Ei);
      end
    end
  end

  % get the S(q,w) on a meshgrid (and possibly rebin/interpolate)
  s = meshgrid(s);
  
  if numel(Ei) > 1
    for index=1:numel(Ei)
      sqw = [ sqw feval(mfilename, s, Ei(index), angles) ];
    end
    s = sqw;
    return
  end
  
  % get axes
  w = getaxis(s,1);
  q = getaxis(s,2);

  % compute Vi
  if isempty(Ki), return; end
  Vi = K2V*Ki;
  % Ei = VS2E*Vi.^2;

  % compute Kf,Ef,Vf,Vi,Ei,lambda for the dynamic range computation
  lambda = 2*pi./Ki;

  Ef = Ei-w;
  
  Vf = SE2V*sqrt(Ef);
  Kf = V2K*Vf;

  fprintf(1, '%s: incoming: Ei=%g [meV] Ki=%g [Angs-1] lambda=%g [Angs] Vi=%g [m/s]\n', ...
    mfilename, Ei, Ki, lambda, Vi);
  fprintf(1, '  q=[%g:%g] w=[%g:%g]\n', min(q(:)), max(q(:)), min(w(:)), max(w(:)));

  % find: cos theta = (ki2 + kf2 - q2)/(2ki kf) is NOT between -1 and 1. theta=diffusion angle
  costheta = (Ki.^2 + Kf.^2 - q.^2) ./ (2*Ki.*Kf);
  if isempty(angles)
    index= find(abs(costheta) > 1 | Ef <= 0);
  else
    if isscalar(angles), angles = [ angles-1 angles+1 ]; end
    if min(angles) < 0 && max(angles) > 0, angles = [ 0 max(abs(angles)) ]; end
    cost = cosd(angles);
    index= find(costheta < min(cost(:)) | costheta > max(cost(:)) | Ef <= 0);
  end
  S.type='()';
  S.subs={ index };
  s = subsasgn(s, S, 0);
  
  if isempty(angles)
    tt = sprintf(' Ei=%g meV', Ei);
  else
    tt = sprintf(' Ei=%g meV [%g:%g deg]', Ei, min(angles), max(angles));
  end
  
  s.DisplayName = strtrim([ s.DisplayName tt ]);
  title(s, [ title(s) tt ]);
  s.Label       = strtrim([ s.Label tt ]);
  s = setalias(s, 'IncidentEnergy', Ei, 'Incident Energy [meV]');
  if ~isempty(angles)
    s = setalias(s, 'DetectionAngles', angles, 'Detection Angles [deg]');
  end
  % compute the angles from 'q' values, and create an Angle alias
  if nargout > 1
    angles = real(acos(costheta))*180/pi; % this is e.g. a 2D array
    sphi = setalias(iData(s), 'Angle', angles, 'Radial Scattering Angle [deg]');
    sphi = setaxis(sphi, 2, 'Angle');
  end
  
  if nargout == 0
    fig=figure; 
    subplot(s);
    set(fig, 'NextPlot','new');
  end

