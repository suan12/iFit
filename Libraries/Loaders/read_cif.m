function [data, this] = read_cif(file)
% read_cif Wrapper to read CIF files
%   data = read_cif(file)
%
% When the argument is a chemical formulae (elements separated with spaces), a
% search in the crystallography open database is made.
%
% this requires proxy settings to be set (when behind a firewall)
%   java.lang.System.setProperty('http.proxyHost', ProxyHost); 
%   com.mathworks.mlwidgets.html.HTMLPrefs.setUseProxy(true);
%   com.mathworks.mlwidgets.html.HTMLPrefs.setProxyHost(ProxyHost);
%   java.lang.System.setProperty('http.proxyPort', num2str(ProxyPort));
%   com.mathworks.mlwidgets.html.HTMLPrefs.setProxyPort(num2str(ProxyPort));
%
% References: 
% CrysFML by Juan Rodriguez-Carvajal and Javier Gonzalez-Platas, ILL and ULL, Tenerife, Spain
%   used to build a powder/Laue Rietveld model, GPL3
%   <http://www.ill.eu/sites/fullprof/php/programs24b7.html>
% Crystallography Open Database <http://www.crystallography.net/>

  data = []; this = [];
  
  % test if the given file is a chemical formulae, in which case we make a query to COD
  if iscellstr(file) || isempty(isdir(file))
    % not a file, we query COD at http://wiki.crystallography.net/howtoquerycod/
    % this requires proxy settings to be set (when behind a firewall), e.g. using miFit Preference
    %   ProxyHost Proxy address if you are behind a proxy [e.g. myproxy.mycompany.com or empty]
    %   ProxyPort Proxy port if you are behind a proxy [8888 or 0 or empty]
    %
    %   java.lang.System.setProperty('http.proxyHost', ProxyHost); 
    %   com.mathworks.mlwidgets.html.HTMLPrefs.setUseProxy(true);
    %   com.mathworks.mlwidgets.html.HTMLPrefs.setProxyHost(ProxyHost);
    %   java.lang.System.setProperty('http.proxyPort', num2str(ProxyPort));
    %   com.mathworks.mlwidgets.html.HTMLPrefs.setProxyPort(num2str(ProxyPort));
    %
    % example: 
    %   urlread('http://www.crystallography.net/cod/result.php?formula=Mg%20O')
    %   curl http://www.crystallography.net/cod/result.php?formula=Mg%20O
    % then search lines with CIF and get number (single or dialogue), then retrieve:
    %   curl -s http://www.crystallography.net/cod/2002926.cif
    
    if iscellstr(file), file = sprintf('%s ', file{:}); end
    file = strrep(strtrim(file), ' ', '%20');  % remove spaces from formula
    
    % query COD
    cod   = urlread([ 'http://www.crystallography.net/cod/result.php?formula=' file ]);
    cod   = textscan(cod, '%s','Delimiter',sprintf('\n\r'));
    cod   = cod{1};
    cod   = cod(find(~cellfun(@isempty, strfind(cod, 'CIF'))));
    % have to read lines until '</tr>'
    index = strfind(cod, '</tr>');
    cod   = cod(find(~cellfun(@isempty, index)));
    index = cell2mat(index);
    for l=1:numel(cod)
      this = cod{l};
      this = this(1:(index(l)-1));
      % remove some of the links '<a href="result.php
      i1 = strfind(this, '<a href="result.php?spacegroup');
      i2 = strfind(this, '</a>');
      if ~isempty(i1) && ~isempty(i2)
        i1 = i1(1); i2=i2(find(i2 > i1, 1));
        this(i1:(i2+3)) = [];
      end
      i3 = strfind(this, '<a href="result.php?journal');
      if ~isempty(i3)
        i3 = i3(1);
        this(i3:end) = [];
      end
      this = strrep(this, '<a href="', '');
      % clean up each CIF line: remove <td> </td> <br/> <i> </i> <b> </b> ...
      for tok={'<td>', '</td>', '<br/>', '<i>', '</i>', '<b>', '</b>', '%20','</a>', '<a href="', '">'}
        this = strrep(this, tok{1}, ' ');
      end
      % the first token in each line is now the COD number
      cod(l) = this;
    end
    
  end
  
  if exist('cif2hkl') == 3 || exist('cif2hkl') == 7 || exist('cif2hkl') == 2
    % use cif2hkl in verbose and no-output-files mode ('-')
    
    if nargin == 0, return; end
    
    if ischar(file) && ~isempty(dir(file))
      this = cif2hkl(file,[],[],'-',1);
      this = str2struct(this);
      this.file = file;
    else
      this = file;
    end
    
    if ~isstruct(this)
      return;
    end
    % search for cell, Atoms and space group
    atoms={'H','He','Li','Be','B','C','N','O','F','Ne','Na','Mg','Al','Si','P','S','Cl','Ar',...
      'K','Ca','Sc','Ti','V','Cr','Mn','Fe','Co','Ni','Cu','Zn','Ga','Ge','As','Se',...
      'Br','Kr','Rb','Sr','Y','Zr','Nb','Mo','Tc','Ru','Rh','Pd','Ag','Cd','In',...
      'Sn','Sb','Te','I','Xe','Cs','Ba','La','Ce','Pr','Nd','Pm','Sm','Eu','Gd',...
      'Tb','Dy','Ho','Er','Tm','Yb','Lu','Hf','Ta','W','Re','Os','Ir','Pt','Au',...
      'Hg','Tl','Pb','Bi','Po','At','Rn','Fr','Ra','Ac','Th','Pa','U','Np','Pu',...
      'Am','Cm','Bk','Cf','Es','Fm','Md','No','Lr','Rf','Db','Sg','Bh','Hs','Mt',...
      'Ds','Rg','Cn','Uut','Uuq','Uup','Uuh','Uuo'};
    f = fieldnames(this);
    for j=1:length(f)
      remove_me = 0;
      % check if the name of the field is <atom> optionally followed by a number
      [at,nb] = strtok(f{j}, '0123456789'); % supposed to be an atom, and nb is a 'number' or empty
      if any(strcmpi(f{j}, {'Spgr','Spg','Group','SpaceGroup','SubG','SpaceG','SPCGRP','Symb'}))
        if isnumeric(this.(f{j})), this.(f{j}) = num2str(this.(f{j})); end
        data.Spgr = strrep(this.(f{j}),'''','"'); remove_me = 1;
      elseif any(strncmpi(f{j}, {'struct','atom'},4))
        data.structure.(f{j}) = this.(f{j}); remove_me = 1;
      elseif any(strcmpi(f{j}, {'cell','lattice'}))
        data.cell = this.(f{j}); remove_me = 1;
      elseif strcmpi(f{j}, 'title')
        data.title = strrep(this.(f{j}),'''','"'); remove_me = 1;
      elseif strcmpi(f{j}, 'file')
        data.file = this.(f{j}); remove_me = 1;
      elseif any(strcmp(at, atoms)) && (isempty(nb) || ~isempty(str2num(nb))) && length(this.(f{j})) >= 3 && length(this.(f{j})) <= 7
        % the name of the field is <atom> optionally followed by a number, and value length is 3-7
        data.structure.(f{j}) = this.(f{j}); remove_me = 1;
      end
      if remove_me, this = rmfield(this, f{j}); end
    end
  else
    disp('cif2hkl is missing: compile it with e.g: ')
    disp('  gfortran -O2 -fPIC -c cif2hkl.f90')
    disp('  mex -O cif2hkl_mex.c cif2hkl.o -o cif2hkl -lgfortran')
    error('Missing cif2hkl MeX')
  end

