try; cd(fileparts(mfilename('fullpath')));catch; end;
try;
   run ../matlab/utilities/initPaths.m
catch
   msgbox({'Please change to the directory where this file is saved before running the rest of this code'},'Change directory'); 
end

buffhost='localhost';buffport=1972;
% wait for the buffer to return valid header information
hdr=[];
while ( isempty(hdr) || ~isstruct(hdr) || (hdr.nchans==0) ) % wait for the buffer to contain valid data
  try 
    hdr=buffer('get_hdr',[],buffhost,buffport); 
  catch
    hdr=[];
    fprintf('Invalid header info... waiting.\n');
  end;
  pause(1);
end;

trialDuration=9;
trlen_ms=trialDuration*1000;
dname  ='training_data';
cname  ='clsfr';


[data,devents,state]=buffer_waitData(buffhost,buffport,[],'startSet',{'Stimulus.action'},'exitSet',{'Stimulus.end'},'trlen_ms',trlen_ms);
mi=matchEvents(devents,'Stimulus.end'); devents(mi)=[]; data(mi)=[]; 
fprintf('Saving %d epochs to : %s\n',numel(devents),dname);
save(dname,'data','devents');
