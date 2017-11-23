function s = deBosify(s, T, type)
% deBosify: remove Bose factor (detailed balance) from an 'experimental' data set.
%
% iData_Sqw2D: bosify: cancel the Bose factor effect, which removes most of the 
%   temperature effect. In principle the resulting data set is 'classical' that 
%   is S(q,w) = S(q,-w)
% The S(q,w) is a dynamic structure factor aka scattering function.
%
% input:
%   s: Sqw data set (non classical, including T Bose factor e.g from experiment)
%        e.g. 2D data set with w as 1st axis (rows, meV), q as 2nd axis (Angs-1).
%   T: when given, Temperature to use for Bose. When not given, the Temperature
%      is searched in the object.
%   type: 'Schofield' or 'harmonic' or 'standard' (default)
%
% conventions:
% omega = Ei-Ef = energy lost by the neutron, given in [meV]
%    omega > 0, neutron looses energy, can not be higher than Ei (Stokes)
%    omega < 0, neutron gains energy, anti-Stokes
% Egelstaff, Eq (9.25) p189
%    S(q,-w) = exp(-hw/kT) S(q,w)
%    S(q,w)  = exp( hw/kT) S(q,-w)
%    S(q,w)  = Q(w) S*(q,w) with S*=classical limit
% for omega > 0, S(q,w) > S(q,-w)
%               
% The semi-classical correction, Q, aka 'quantum' correction factor, 
% can be selected from the optional   'type' argument:
%    Q = exp(hw_kT/2)                 'Schofield' or 'Boltzmann'
%    Q = hw_kT./(1-exp(-hw_kT))       'harmonic'  or 'Bader'
%    Q = 2./(1+exp(-hw_kT))           'standard'  or 'Frommhold' (default)
%
% The 'Boltzmann' correction leads to a divergence of the S(q,w) for e.g. w above 
% few 100 meV. The 'harmonic' correction provides a reasonable correction but does
% not fully avoid the divergence at large energies.
%
%  Bose factor: n(w) = 1./(exp(w*11.605/T) -1) ~ exp(-w*11.605/T)
%               w in [meV], T in [K]
%
% Example: s=iData_Sqw2D('SQW_coh_lGe.nc'); sb=Bosify(s, 300); s0=deBosify(sb);
%
% See also: Bosify, symmetrize, Sqw_dynamic_range, Sqw_scatt_xs
% (c) E.Farhi, ILL. License: EUPL.
  
  if nargin < 2, T = []; end
  if nargin < 3, type=''; end
  if isempty(type), type='standard'; end
  
  s = Bosify(s, -T, type);
  

  
