% experiment part 1 FES_BCI

clear all
close all

try; cd(fileparts(mfilename('fullpath')));catch; end;
try;
    run ../../matlab/utilities/initPaths.m
catch
    msgbox({'Please change to the directory where this file is saved before running the rest of this code'},'Change directory');
end

%% define variables
neutralColor  =[0 1 0]; %green
fastColor =[1 0 0]; %red
slowColor =[0 0 1]; %blue
textColor=[1 1 1]; % white

% make the target sequence
nSeq = 10;
baselineDuration = 2;
trialDuration=15;
interTrialDuration=1;
feedbackDuration=2;
minrand=-2;
maxrand=2;
rtFES=[];
rthuman=[];
sim_time=2;
nr_blocks=2;
nr_taps=0;
correct_time=0;
max_FES=12;
min_FES=3;

% durations for the labelling
eventInterval    =.25; % send event every this long...
startupArtDur    =1;
endArtDur        =1;
nonMoveLowerBound=-2;
nonMoveUpperBound=.75;
moveLowerBound   =-.5;
moveUpperBound   =.25;

% make the stimulus
clf;
fig=gcf;
set(fig,'color',[0 0 0],'toolbar','none','menubar','none'); % black figure
set(fig,'Units','pixel');wSize=get(fig,'position');fontSize = .05*wSize(4);
axes('position',[0 0 1 1],'visible','off','xlim',[0 1],'ylim',[0 1],'nextplot','add','color',[0 0 0]);

fixcross=text(.5,.5,'+','HorizontalAlignment','center','VerticalAlignment','middle',...
    'FontUnits','pixel','fontsize',.05*wSize(4),'color',textColor,'visible','off');
msgh=text(.5,.5,'+','HorizontalAlignment','center','VerticalAlignment','middle',...
    'FontUnits','pixel','fontsize',.05*wSize(4),'color',textColor,'visible','off');
square=rectangle('position',[.5 .5 .5 .5],'curvature',[0 0],'facecolor',neutralColor,'visible','off'); % position = [x y width height]

instruct=instructions(); % define instructions
question=initquestion(); % define question
FEStrialmsgh=initFEStrialmsgh(); % define FES trial
%% connect to buffer
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

% set the real-time-clock to use
initgetwTime;
initsleepSec;

state= [];
endExp=false;
while (~endExp)
    [events, state]= buffer_newevents(buffhost,buffport,state);
    
    % install listener for key-press mode change
    set(fig,'keypressfcn',@(src,ev) set(src,'userdata',char(ev.Character(:))));
    set(fig,'userdata',[]);
    set(msgh,'string',instruct,'visible','on');drawnow;
    waitforbuttonpress;
    set(msgh,'string','');
    drawnow;
    
    human_stats=struct('N',0,'sx',0,'sx2',0,'mu',0,'var',0);
    
    % decide on the FES trials only
    FES_trial=sort(randperm(nSeq,(nSeq*0.1))); %pick 10% of trials in block to be FES trials
    
    % play the stimulus
    sendEvent('stimulus.buttonpress','start');
    for b=1:nr_blocks
        sendEvent('stimulus.block',b);
        for si=1:nSeq;
            nr_taps=nr_taps+1;
            
            % reset the cue and fixation point to indicate trial has finished
            set(msgh,'string','+','visible','off');
            drawnow;
            
            % inter-trial
            sleepSec(interTrialDuration);
            
            if si == FES_trial
                init_FEStrial(FEStrialmsgh, msgh, si);
                sleepSec(3);
            end
            
            % baseline
            set(msgh,'string','+','visible','on','color',[1 1 1]); drawnow;
            sendEvent('stimulus.baseline','start');
            sleepSec(baselineDuration);
            
            % trialstart
            set(fixcross,'string','+','visible','off','color',[1 1 1]); drawnow;
            set(msgh,'string',question,'visible','off');drawnow;
            startsize=0.2;
            set(square,'position',[.5-startsize/2 .5-startsize/2 startsize startsize],'facecolor',neutralColor,'visible','on');drawnow;
            set(msgh,'string','+','visible','on','color',[1 1 1]); drawnow;
            sendEvent('stimulus.trial','start');
            
            samp0=buffer('poll');samp0=samp0.nSamples;
            t0=getwTime(); % get time trial start
            % run the waiting loop
            t_now=0;
            t_human=inf;
            
            % decide on the FES move time estimate
            t_FES= (max_FES - min_FES).*rand(1,1)+min_FES; %t_FES= (.5+(1-.5)*rand(1))*trialDuration;
            if nr_taps > 10
                t_FES= (human_stats.mu+(minrand-maxrand).*rand(1,1));
            end
            fprintf('%d) t_FES = %g    (%g,%g)\n',si,t_FES,human_stats.mu,human_stats.var);
            %------------------------------------- Run the trial -----------------------------
            set(fig,'userdata',[]); % clear the key buffer
            checkKeys = true; % listen for keypresses from the human
            FES_first = false;
            human_first = false;
            
            while ( t_now < trialDuration ) %until trial end
                t_now = getwTime()-t0; % get current trial-time
                drawnow; % crucial!! If you don't do this, 'userdata' is not updated!
                
                if ( ~ishandle(fig) ) % check whether the Matlab window is still controllable
                    break
                end
                
                % process human key-presses
                if checkKeys %while human has not pressed a button yet
                    modekey=get(fig,'userdata');
                    if ( ~isempty(modekey) ) % if there is a key press
                        t_human = t_now; % save it
                        t_move=getwTime()-t0; % move time, rel trial start
                        sendEvent('FES_on', 1);
                        sendEvent('EMG_triggered', t_human); % notify the buffer
                        set(fig,'userdata',[]);
                        rthuman=[rthuman t_human];
                        checkKeys = false; % stop listening for keypresses from the human
                    end
                end
                
                if ~FES_first && ~human_first % while nobody has pressed yet
                    set(square,'position',[.5-startsize/2 .5-startsize/2 startsize startsize],'facecolor',neutralColor,'visible','on'); drawnow;
                    set(msgh,'string','+','visible','on','color',[1 1 1]); drawnow;
                    
                    if( t_FES < t_human && t_FES < t_now ) % FES first
                        sendEvent('FES_on', 1);
                        sendEvent('random_triggered', t_FES); % notify the buffer
                        rt_FES = sendEvent('response.comp',t_FES);
                        mevt=sendEvent('response.button','FES'); % send info event
                        drawnow;
                        rtFES=[rtFES t_FES];
                        drawnow;
                        t_move=getwTime()-t0; % move time, rel trial start
                        samp_move=mevt.sample;
                        FES_first = true;
                        break;
                    end
                    
                    if( t_human < t_FES && t_human < t_now) % human first
                        rt_human = sendEvent('response.human', t_human);
                        mevt=sendEvent('response.button','human'); % send info event
                        drawnow;
                        samp_move=mevt.sample;
                        drawnow;
                        human_first = true;
                        break;
                    end
                end
            end
            
            sendEvent('intention_question','start');
            set(square,'position',[.5-startsize/2 .5-startsize/2 startsize startsize],'facecolor',neutralColor,'visible','off'); drawnow;
            set(msgh,'string',question,'visible','on','color',[1 1 1]);drawnow;
            waitforbuttonpress;
            
            % init feedback
            set(square,'position',[.5-startsize/2 .5-startsize/2 startsize startsize],'facecolor',neutralColor,'visible','off');
            set(msgh,'string',question,'visible','off','color',[1 1 1]);drawnow;
            [feedback, correct_time]=initfeedback(correct_time, t_move, square, startsize, fastColor, slowColor, neutralColor); drawnow;
            sendEvent('feedback', 'start');
            sleepSec(feedbackDuration);
            set(square,'position',[.5-startsize/2 .5-startsize/2 startsize startsize],'facecolor',neutralColor,'visible','off'); drawnow;
            
            if ( ~ishandle(fig) ) break; end;
            t_end  = getwTime()-t0;
            t_move = min(t_human,t_FES); % move time for either party
            
            % --------------------------  send the labelling events ----------------------------------
            nSamp=buffer('poll');
            if( t_human<t_FES )  % human moved:     startupArt < t < t_human - nonMoveLowerBound
                t_evt=startupArtDur:eventInterval:t_human+nonMoveLowerBound;
            else                      % computer moved:  startupArt < t < t_FES
                t_evt=startupArtDur:eventInterval:t_FES;
            end
            for ei=1:numel(t_evt);
                tei     = t_evt(ei);
                samp_evt= tei*(samp_move-samp0)./t_move + samp0; % linearly interpolate the event sample number
                sendEvent('stimulus.target','nonmove',samp_evt);
            end
            if( t_human < t_FES ) % human moved : t_move + moveLowerBound < t < t_human+moveUpperBound
                t_evt=t_human+moveLowerBound:eventInterval:t_human+moveUpperBound;
                for ei=1:numel(t_evt);
                    tei     = t_evt(ei);
                    samp_evt= tei*(samp_move-samp0)./t_human + samp0;
                    sendEvent('stimulus.target','move',samp_evt);
                end
            end
            % post move
            % t_move + nonMoveUpperBound < t < end-endArt
            t_evt = t_move+nonMoveUpperBound:eventInterval:t_end+endArtDur;
            for ei=1:numel(t_evt);
                tei     = t_evt(ei);
                samp_evt= tei*(samp_move-samp0)./t_move + samp0;
                sendEvent('stimulus.target','nonmove',samp_evt);
            end
            sendEvent('stimulus.trial','end');
            
            %-------------------------------------- update the human move tracking stats
            if t_human==Inf; %simulate the human time if computer won
                t_human= t_FES+ sim_time;
            end;
            
            human_stats.N   = human_stats.N  + 1;
            human_stats.sx  = human_stats.sx + t_human;
            human_stats.sx2 = human_stats.sx2+ t_human.^2;
            human_stats.mu  = human_stats.sx ./ human_stats.N; % mean
            human_stats.var = (human_stats.sx2 - human_stats.sx.^2./human_stats.N)./human_stats.N; %var
        end
        
        %break with feedback on blocks
        set(square,'visible','off'); set(msgh,'visible','off'); set(fixcross,'visible','off');drawnow;
        sendEvent('stimulus.block','feedback');
        
        block_msg=initBlock(msgh, b, nr_blocks, correct_time);
        sendEvent('stimulus.break', 'start');
        waitforbuttonpress;
        sendEvent('stimulus.break', 'end');
    end
    sendEvent('stimulus.sentences','end');
    
    % show end message
    set(square,'visible','off'); set(fixcross,'visible','off');set(msgh,'visible','off');
    set(msgh,'string',{'Thank you for participating!'},'visible','on');drawnow;
    sendEvent('experiment','end');
    endExp=true;
end










