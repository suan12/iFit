function  [s,parameters,fields] = Sqw_parameters(s, fields)
% [s,p,fields] = Sqw_parameters(s,type): search for parameter values in a Sqw/Sab data set
%
% input:
%   s: any iData object, including S(q,w) and S(alpha,beta) ones.
%   fields: an optional list of items to search (cellstr)
% output:
%   s: updated object with found parameters
%   p: parameters as a structure, also stored into s.parameters

% extract a list of parameters
parameters = [];

if nargin == 0, return; end
if ~isa(s, 'iData')
  disp([ mfilename ': ERROR: The data set should be an iData object, and not a ' class(s) ]);
  return; 
end
if nargin < 2, fields=[]; end
if isempty(fields) % default: search all parameters and assemble them
  [s,parameters1,fields1] = Sqw_parameters(s, 'sqw');
  [s,parameters2,fields2] = Sqw_parameters(s, 'sab');
  % merge the structures/cells handling duplicated fields
  f = [ fieldnames(parameters1) ; fieldnames(parameters2) ];
  [pnames,index] = unique(f);
  pairs = [fieldnames(parameters1), struct2cell(parameters1); ...
           fieldnames(parameters2), struct2cell(parameters2)].';
  parameters = struct(pairs{:,index});
  fields = [ fields1 fields2 ];
  fields = fields(index);
  s.parameters=parameters(1);
  return
end

if ischar(fields) && strcmpi(fields, 'sqw')
  % a list of parameter names, followed by comments
  % aliases can be specified when a parameter is given as a cellstr, with 
  % consecutive possibilities.
  fields={ ...
      'density [g/cm3] Material density'	...
     {'weight [g/mol] Material molar weight'	'mass' 'AWR'}...
      'T_m [K] Melting T'	...
      'T_b [K] Boiling T'	'MD_at Number of atoms in the molecular dynamics simulation'	...
      'MD_box [Angs] Simulation box size'	...
     {'Temperature [K]' 'T' 'TEMP'}	...
      'dT [K] T accuracy' ...
      'MD_duration [ps] Molecular dynamics duration'	'D [cm^2/s] Diffusion coefficient' ...
      'sigma_coh [barn] Coherent scattering neutron cross section' ...
      'sigma_inc [barn] Incoherent scattering neutron cross section'	...
      'sigma_abs [barn] Absorption neutron cross section'	...
      'c_sound [m/s] Sound velocity' ...
      'At_number Atomic number Z' ...
      'Pressure [bar] Material pressure' ...
      'v_sound [m/s] Sound velocity' ...
      'Material Material description' ...
      'Phase Material state' ...
      'Scattering process' ...
     {'Wavelength [Angs] neutron wavelength' 'lambda' 'Lambda' }...
      'Instrument neutron spectrometer used for measurement' ...
      'Comment' ...
      'C_s [J/mol/K]   heat capacity' ...
      'Sigma [N/m] surface tension' ...
      'Eta [Pa s] viscosity' ...
      'L [J/mol] latent heat' ...
     {'classical [0=from measurement, with Bose factor included, 1=from MD, symmetric]' 'symmetry' } ...
      'multiplicity  [atoms/unit cell] number of atoms/molecules per scattering unit cell' ...
     {'IncidentEnergy [meV] neutron incident energy' 'fixed_energy' 'energy' 'ei' 'Ei'} ...
     {'IncidentWavevector [Angs-1] neutron incident wavevector' 'ki' 'Ki'} ...
     {'Distance [m] Sample-Detector distance' 'distance' } ...
     {'ChannelWidth [time unit] ToF Channel Width' } ...
     {'V_rho [Angs^-3] atom density' 'rho' } ...
    };
elseif ischar(fields) && strcmpi(fields, 'sab')
  % ENDF compatibility flags: MF1 MT451 and MF7 MT2/4
  fields = { ...
    'MAT' ...
    'MF' ...
    'MT' ...
    'ZA' ...
   {'weight [g/mol] Material molar weight'	'mass' 'AWR'} ...
   {'classical [0=from measurement, with Bose factor included, 1=from MD, symmetric]' 'symmetry' } ...
   {'Temperature [K]' 'T' 'TEMP'}	...
    'sigma_coh [barn] Coherent scattering neutron cross section' ...
    'sigma_inc [barn] Incoherent scattering neutron cross section'	...
    'sigma_abs [barn] Absorption neutron cross section'	...
    'At_number Atomic number Z' ...
    'Scattering process' ...
    'Material' ...
    'charge' ...
    'EDATE' ...
    'LRP' ...
    'LFI' ...
    'NLIB' ...
    'NMOD' ...
    'ELIS' ...
    'STA' ...
    'LIS' ...
    'LISO' ...
    'NFOR' ...
    'AWI' ...
    'EMAX' ...
    'LREL' ...
    'NSUB' ...
    'NVER' ...
    'TEMP' ...
    'LDRV' ...
    'NWD' ...
    'NXC' ...
    'ZSYNAM' ...
    'ALAB' ...
    'AUTH' ...
    'REF' ...
    'DDATE' ...
    'RDATE' ...
    'ENDATE' ...
    'HSUB' ...
    'SB' 'NR' 'NP' 'LTHR' 'S' 'E' 'LT' ...
    'LAT' 'LASYM' 'B' 'NI' 'NS' 'LLN' 'NT' 'Teff' ...
        };
end

% add parameters by searching field names from 'fields' in the object
for index=1:length(fields)
  f = fields{index};
  if ischar(f), f= {f}; end
  for f_index=1:numel(f)
    name   = strtok(f{f_index});
    p_name = strtok(f{1});
    if ~isfield(parameters, p_name)
      if isfield(s, name)
        parameters.(p_name) = get(s, name);
      elseif isfield(s.Data, name)
        parameters.(p_name) = s.Data.(name);
      elseif isfield(s.Data, name)
        parameters.(p_name) = s.Data.(name);
      elseif ~isempty(findfield(s,name,'exact'))
        parameters.(p_name) = get(s, findfield(s,name,'exact'));
      end
    end % parameter alias names
  end
  fields{index} = f{1};
end

% now transfer parameters into the object, as alias values
s=setalias(s, 'parameters', parameters, 'Material parameters');
for index=1:numel(fields)
  [name, comment] = strtok(fields{index});
  if isfield(parameters, name)
    val = parameters.(name);
    % if isnumeric(val) && ~isscalar(val), val=val(1); end
    s=setalias(s, name, val, strtrim(comment));
  end
end
