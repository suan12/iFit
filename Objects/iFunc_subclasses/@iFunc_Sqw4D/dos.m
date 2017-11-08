function [DOS, DOS_partials] = dos(s, n)
% iFunc_Sqw4D: dos: compute the density of states (vDOS)
%
%  The routine can be used for 4D models.
%    when used on 4D models S(HKL,w), the vDOS is computed.
%
%    DOS = sqw_phonon_dos(s)    returns the vibrational density of states (vDOS)
%      the vDOS and the partials per mode are also stored in the UserData.
%    DOS = sqw_phonon_dos(s, n) does the same with n-bins on the vDOS (n=100)
%
%    When the DOS has already been computed, it is used as is. To force a
%    recomputation, specify a different number of bins 'n' or set:
%      s.UserData.DOS=[];
%
%    To smooth the resulting distribution, use:
%      sDOS = smooth(DOS); plot(sDOS);
%
% input:
%   s: S(q,w) 4D model (iFunc_Sqw4D)
%   n: number of low-angle values to integrate (integer). Default is 10 when omitted.
%
% output:
%   DOS:   DOS(w)   (1D iData versus energy)
%
% conventions:
% omega = Ei-Ef = energy lost by the neutron
%    omega > 0, neutron looses energy, can not be higher than Ei (Stokes)
%    omega < 0, neutron gains energy, anti-Stokes
%
% Example: Sqw=sqw_cubic_monoatomic; D=dos(Sqw);
% (c) E.Farhi, ILL. License: EUPL.

  DOS=[]; DOS_partials=[];
  if nargin == 0, return; end
  if nargin < 2, n = []; end
  
  % handle array of objects
  if numel(s) > 1
    for index=1:numel(s)
      DOS = [ DOS feval(mfilename, s(index), method, n) ];
    end
    if ~isempty(inputname(1))
      assignin('caller',inputname(1),s);
    end
    return
  end

  % compute
  [DOS, DOS_partials, s] = sqw_phonon_dos_4D(s, n);
  if ~isempty(inputname(1))
    assignin('caller',inputname(1),s);
  end
  
  % plot
  if nargout == 0 
    fig=figure;
    DOS = s.UserData.DOS;
    xlabel(DOS,[ 'Energy' ]);
    % plot any partials first
    if isfield(s.UserData,'DOS_partials') && numel(s.UserData.DOS_partials) > 0
      d=s.UserData.DOS_partials;
      for index=1:numel(d)
        this_pDOS=d(index);
        this_pDOS{1} = this_pDOS{1};
        d(index) = this_pDOS;
      end
      h=plot(d);
      if iscell(h), h=cell2mat(h); end
      set(h,'LineStyle','--');
      hold on
    end
    % plot total DOS and rotate
    h=plot(DOS); set(h,'LineWidth',2);
  end
  
% ------------------------------------------------------------------------------

function [DOS, DOS_partials, s] = sqw_phonon_dos_4D(s, n)
  % sqw_phonon_dos_4D: compute the phonon/vibrational density of states (vDOS)
  %
  % input:
  %   s: phonon S(q,w) (4D) Model or Data set (iFunc/iData)
  %
  % output:
  %   DOS:          phonon/vibrational density of states (iData)
  %   DOS_partials: phonon/vibrational density of state partials (iData array)
  %
  % Example: DOS=sqw_phonon_dos(sqw_cubic_monoatomic('defaults'))
  % (c) E.Farhi, ILL. License: EUPL.

  DOS = []; f=[]; DOS_partials = [];
  
  % must be 4D iFunc or iData
  if ~nargin
    return
  end
  
  if nargin < 2, n=[]; end
  
  % first get a quick estimate of the max frequency
  if  ~isfield(s.UserData,'DOS') || isempty(s.UserData.DOS) || (~isempty(n) && prod(size(s.UserData.DOS)) ~= n)
    qh=linspace(-.5,.5,10);qk=qh; ql=qh; w=linspace(0.01,50,11);
    f=iData(s,[],qh,qk,ql',w);
    if isfield(s.UserData, 'FREQ') && ~isempty(s.UserData.FREQ)
      s.UserData.maxFreq = max(s.UserData.FREQ(:));
      disp([ mfilename ': maximum phonon energy ' num2str(max(s.UserData.maxFreq)) ' [meV] in ' s.Name ]);
    end
    if ~isfield(s.UserData, 'maxFreq') || isempty(s.UserData.maxFreq) ...
      || ~isfinite(s.UserData.maxFreq) || s.UserData.maxFreq <= 0
      s.UserData.maxFreq = 100;
    end
    
    % evaluate the 4D model onto a mesh filling the Brillouin zone [-0.5:0.5 ]
    s.UserData.DOS     = [];  % make sure we re-evaluate again on a finer grid
    s.UserData.maxFreq = max(s.UserData.maxFreq(:));
    qh=linspace(-0.5,.5,50);qk=qh; ql=qh; w=linspace(0.01,s.UserData.maxFreq*1.2,51);
    f=iData(s,[],qh,qk,ql',w);
  end
  
  if (~isfield(s.UserData,'DOS') || isempty(s.UserData.DOS)) ...
    && isfield(s.UserData,'FREQ') && ~isempty(s.UserData.FREQ)
    nmodes = size(s.UserData.FREQ,2);
    if isempty(n)
      n = max(nmodes*10, 100);
    end
    index= find(imag(s.UserData.FREQ) == 0);
    dos_e = s.UserData.FREQ(index);
    omega_e = linspace(0,max(dos_e(:))*1.2, n);
    [dos_e,omega_e]=hist(dos_e,omega_e);
    dos_factor = size(s.UserData.FREQ,2) / trapz(omega_e(:), dos_e(:));
    dos_e = dos_e * dos_factor ; % 3n modes per unit cell
    DOS=iData(omega_e,dos_e);
    DOS.Title = [ 'Total DOS ' s.Name ];
    DOS.Label = '';
    xlabel(DOS,'Energy [meV]'); 
    ylabel(DOS,[ 'Total DOS/unit cell ' strtok(s.Name) ]);
    DOS.Error=0; s.UserData.DOS=DOS;
    % partial phonon DOS (per mode) when possible
    pDOS = [];
    for mode=1:nmodes
      f1 = s.UserData.FREQ(:,mode);
      index = find(imag(f1) == 0);
      dos_e = hist(f1(index),omega_e, n);
      dos_e = dos_e * dos_factor ; % normalize to the total DOS
      DOS=iData(omega_e,dos_e);
      DOS.Title = [ 'Mode [' num2str(mode) '] DOS ' s.Name ]; 
      DOS.Label = '';
      xlabel(DOS,'Energy [meV]'); 
      ylabel(DOS,[ 'Partial DOS[' num2str(mode) ']/unit cell ' strtok(s.Name) ]);
      DOS.Error = 0;
      pDOS = [ pDOS DOS ];
    end
    s.UserData.DOS_partials=pDOS;
    clear f1 index dos_e omega_e dos_factor DOS pDOS
  end
  
  if ~isempty(inputname(1))
    assignin('caller',inputname(1),s);
  end

  % get the DOS and other output
  if isfield(s.UserData,'DOS') && ~isempty(s.UserData.DOS)
    DOS = s.UserData.DOS;
  end
  if isfield(s.UserData,'DOS_partials') && numel(s.UserData.DOS_partials) > 0
    DOS_partials = s.UserData.DOS_partials;
  end
   
