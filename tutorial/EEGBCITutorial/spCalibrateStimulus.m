% make the stimulus
fig=figure(2);clf;
set(fig,'Name','Matrix Speller','color',[0 0 0],'menubar','none','toolbar','none','doublebuffer','on');
ax=axes('position',[0.025 0.025 .975 .975],'units','normalized','visible','off','box','off',...
        'xtick',[],'xticklabelmode','manual','ytick',[],'yticklabelmode','manual',...
        'color',[0 0 0],'DrawMode','fast','nextplot','replacechildren',...
        'xlim',[-1.5 1.5],'ylim',[-1.5 1.5],'Ydir','normal');
set(fig,'Units','pixel');wSize=get(fig,'position');set(fig,'units','normalized');% win size in pixels
[h]=initGrid(symbols);

                       % make a connection to the buffer for trigger messages
trigsocket=javaObject('java.net.DatagramSocket'); % creat UDP socket and bind to triggerport
trigsocket.connect(javaObject('java.net.InetSocketAddress','localhost',8300)); 


% make the target stimulus sequence
[ans,ans,ans,ans,tgtSeq]=mkStimSeqRand(numel(symbols),nSeq);
% make the row/col flash sequence for each sequence
[stimSeqRow]=mkStimSeqRand(size(symbols,1),nRepetitions*size(symbols,1));
[stimSeqCol]=mkStimSeqRand(size(symbols,2),nRepetitions*size(symbols,2));

% play the stimulus
% reset the cue and fixation point to indicate trial has finished  
set(h(:),'color',bgColor*.5);
sendEvent('stimulus.training','start');
pause(3);
% Waik for key-press to being stimuli
instructh=text(mean(get(ax,'xlim')),mean(get(ax,'ylim')),spInstruct,...
		 'HorizontalAlignment','center','color',[0 1 0],'fontunits','pixel','FontSize',.07*wSize(4));
% wait for button press to continue
waitforbuttonpress;
set(instructh,'visible','off');
drawnow;

sleepSec(1);
lastPause=0;
for si=1:nSeq;

  if ( ~ishandle(fig) ) break; end;
  if( si>lastPause+nPauseSeq ) % regular subject pauses
    set(instructh,'string',spPauseInstruct,'visible','on');drawnow;
    waitforbuttonpress;
    set(instructh,'visible','off');drawnow;
    sleepSec(1);    
    lastPause=si;
  else % standard inter-sequence delay
    sleepSec(interSeqDuration);
  end
  
  sendEvent('stimulus.sequence','start');
  % show the subject cue where to attend
  [tgtRow,tgtCol]=ind2sub(size(symbols),tgtSeq(si)); % convert to row/col index
  set(h(tgtRow,tgtCol),'color',tgtColor);
  drawnow;% expose; % N.B. needs a full drawnow for some reason
  sendEvent('stimulus.targetSymbol',symbols{tgtSeq(si)});
  fprintf('%d) tgt=%s : ',si,symbols{tgtSeq(si)}); % debug info
  sleepSec(cueDuration);  
  set(h(:),'color',bgColor); % rest all symbols to background color
  
  % rows stimulus
  for ei=1:size(stimSeqRow,2);
    set(h(:),'color',bgColor);
    set(h(stimSeqRow(:,ei)>0,:),'color',flashColor);
    drawnow;
    ev=sendEvent('stimulus.rowFlash',stimSeqRow(:,ei)); % indicate this row is 'flashed'
    if( stimSeqRow(tgtRow,ei)>0 )
      sendEvent('stimulus.tgtFlash',TARGETNAME,ev.sample); % indicate if it was a 'target' flash
    else
      sendEvent('stimulus.tgtFlash',NONTARGETNAME,ev.sample); % indicate if it was a 'target' flash
    end
    try; trigsocket.send(javaObject('java.net.DatagramPacket',stimSeqRow(tgtRow,ei),1));catch;end;
    sleepSec(stimDuration);
  end
  
  % cols stimulus
  for ei=1:size(stimSeqCol,2);
    set(h(:),'color',bgColor);
    set(h(:,stimSeqCol(:,ei)>0),'color',flashColor);
    drawnow;
    ev=sendEvent('stimulus.colFlash',stimSeqCol(:,ei)); % indicate this row is 'flashed'
    if( stimSeqCol(tgtCol,ei)>0 )
      sendEvent('stimulus.tgtFlash',TARGETNAME,ev.sample); % indicate if it was a 'target' flash
    else
      sendEvent('stimulus.tgtFlash',NONTARGETNAME,ev.sample); % indicate if it was a 'target' flash
    end
    try; trigsocket.send(javaObject('java.net.DatagramPacket',stimSeqCol(tgtCol,ei),1)); catch;end;
    sleepSec(stimDuration);
  end
   
  % reset the cue and fixation point to indicate trial has finished  
  set(h(:),'color',bgColor);
  drawnow;
  sendEvent('stimulus.sequence','end');
  fprintf('\n');
end % sequences

set(instructh,'string',{'That ends the training phase.','Do a final check on your brain-signals','Press a key to finish'},'visible','on');drawnow;
waitforbuttonpress;
set(instructh,'visible','off');drawnow;
% end training marker
sendEvent('stimulus.training','end');
