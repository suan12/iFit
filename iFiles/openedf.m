function out = openedf(filename)
%OPENEDF Open an EDF ESRF Data Format file, display it
%        and set the 'ans' variable to an iData object with its content

out = iData(filename);
subplot(out);

if ~isdeployed
  assignin('base','ans',out);
  ans = out
end
