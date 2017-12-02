classdef iData_Sqw2D < iData
  % iData_Sqw2D: create a 2D S(q,w) data set (iData flavour)
  %
  % The iData_Sqw2D class is a 2D data set holding a S(q,w) dynamic structure factor.
  %
  % Example: s=iData_Sqw2D('SQW_coh_lGe.nc')
  %
  % Useful methods for this iData flavour:
  %
  % methods(iFunc_Sqw4D)
  %   all iFunc methods can be used.
  % iData_Sqw2D(s)
  %   convert input [e.g. a 2D iData object] into an iData_Sqw2D to give access to
  %   the methods below.
  % d = dos(s)
  %   Compute the generalized vibrational density of states (gDOS).
  % t = thermochemistry(s)
  %   Compute and display thermochemistry quantities.
  % m = moments(s)
  %   Compute the S(q,w) moments/sum rules (harmonic frequencies).
  % sym = symmetrize(s)
  %   Extend the S(|q|,w) in both energy sides.
  % sb = Bosify(s)
  %   Apply the 'Bose' factor (detailed balance) to a classical data set.
  % s  = deBosify(sb)
  %   Remove Bose factor (detailed balance) from an 'experimental/quantum' data set.
  % p = parseparams(s)
  %   Search for physical quantities in S(q,w) data set.
  %
  % input:
  %   can be an iFunc or struct or any set of parameters to generate a Sqw4D object.
  %   when not given an iFunc, the parameters to sqw_phonons are expected.
  %
  % output: an iData_Sqw2D object
  %
  % See also: iData

  properties
  end
  
  methods
    % main instantiation method
    function obj = iData_Sqw2D(s)
      % iData_Sqw2D: create the iData_Sqw2D subclass
      %
      % input:
      %   must be a 2D iData object holding a S(q,w), S(phi,t), S(alpha,beta) or S(phi,w)
      %
      % Example: s=iData_Sqw2D('SQW_coh_lGe.nc');
      obj = obj@iData;
      obj.class = mfilename;
      
      if ~nargin, return; end  % empty object
      
      % convert/test
      if ~isa(s, mfilename), m = Sqw_check(s); else m=s; end
      if ~isa(m, 'iData') || isempty(m) || ndims(m) ~= 2
        error([ mfilename ': the given input ' class(s) ' does not seem to be convertible to iData_Sqw2D.' ])
      end
      
      % transfer properties
      % this is a safe way to instantiate a subclass
      warning off MATLAB:structOnObject
      m = struct(m);
      for p = fieldnames(m)'
        obj.(p{1}) = m.(p{1});
      end
      obj.class = mfilename;
 
    end % iData_Sqw2D constructor
    
    % parameters (search for parameters in iData)
    function parameters = parseparams(s)
      % iData_Sqw2D: parseparams: search for physical quantities in object.
      % This search is also done when creating iData_Sqw2D objects.
      [s,parameters,fields] = Sqw_parameters(s);
    end

    % structure_factor (sq)
    
    % symmetrize (+/-)
    % dynamic_range
    % scattering_cross_section
    
    % dos (gDOS)
    % thermochemistry
    
    % sound_velocity ?
    % MSD ?
    % diffusion constant ?
    % compressibility ?
    % g(r) pdf
    
    function f = iData(self)
      % iData_Sqw2D: iData: convert a single iData_Sqw2D back to iData
      f = iData;
      self = struct(self);
      w = warning('query','iData:subsasgn');
      warning('off','iData:subsasgn');
      for p = fieldnames(self)'
        f.(p{1}) = self.(p{1}); % generates a warning when setting Alias
      end
      warning(w);
    end
    
    function spe = q2phi(self)
      % iData_Sqw2D: q2phi: convert a S(q,w) into a S(phi,w) iData
      spe = Sqw_q2phi(self);
    end
    
    function f = saveas(self, varargin)
      % iData_Sqw2D: saveas: save S(q,w) into a file.
      % all iData.saveas formats are available, and in addition:
      %
      %   McStas (for Isotropic_Sqw component)
      %   INX (MuPhoCor)
      %   SPE (MSlice)
      %
      if numel(varargin) >= 2
        switch lower(varargin{2})
        case {'mcstas','sqw'}
          f = Sqw_McStas(self, varargin{1});
        case 'inx'
          spe = Sqw_q2phi(self);  % S(phi, w)
          f = write_inx(spe, varargin{1});
        case 'spe'
          spe = Sqw_q2phi(self);  % S(phi, w)
          f = write_spe(spe, varargin{1});
        otherwise
          f = saveas@iData(self, varargin{:});
        end
      else
        f = saveas@iData(self, varargin{:});
      end
      
    end
    
  end
  
end
