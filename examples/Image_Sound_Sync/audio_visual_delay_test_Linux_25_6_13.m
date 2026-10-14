clear;clc;
close all;
%% subject info
% prompt = {'编号','性别（1=男性，2=女性）','年龄','利手（1=右手，2=左手）','session'};
% dlg_title = 'Subject Info';
% num_line = [1 50];
% def_answer = {'S01','1','20','1','1'};
% subinfo = inputdlg(prompt,dlg_title,num_line,def_answer);

try
    %priorityLevel=MaxPriority([]);
    priorityLevel=99;
    Priority(priorityLevel);
    %% trigger
    port = '/dev/ttyUSB0';
    [handle,errmsg] = IOPort('OpenSerialPort',port,['Parity=none','BaudRate=921600']);
    IOPort('Write',handle,uint8(0));

    %% Parameters Define
    format shortg;
    durtone = 0.05;
    duration_image=0.05;
    number_target = 60:65;
    number_nontarget = 1000;
    duration_press_key = 0.1;%s
    block = 1;
    cnt = 0;
    nontar_num = randperm(number_nontarget);
    tar_num = 1E7+randperm(number_target(randi(numel(number_target))));
    total = [tar_num nontar_num];
    total = total(:,randperm(size(total,2)));
    ResTime = zeros(length(tar_num),3);   % 1类型；2反应时；3正确率
    freq = [1000,500];
    sf = 48000;
    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');
    running = 1;

    %% Initialise soundcard and acoustic setup
    InitializePsychSound(1);
    pahandle1 = PsychPortAudio('Open', 0, 1, 3, sf, 2,1);   % standard stimuli
    PsychPortAudio('Volume', pahandle1, 1);
    [myBeep1, samplingRate1] = MakeBeep(freq(1),durtone, sf);
    %PsychPortAudio('FillBuffer', pahandle1, [myBeep1; myBeep1]);
    PsychPortAudio('RunMode', pahandle1, 1);


    % pahandle2 = PsychPortAudio('Open', 4, 1, 3, sf, 2,128);   % deviant stimuli
    % PsychPortAudio('Volume', pahandle2, 0.5);
    [myBeep2, samplingRate2] = MakeBeep(freq(2),durtone, sf);
    % PsychPortAudio('FillBuffer', pahandle2, [myBeep2; myBeep2]);
    % PsychPortAudio('RunMode', pahandle2, 1);
    
    here = fileparts(mfilename('fullpath'));
    image = imread(fullfile(here, 'square.jpg'));
    square = imread(fullfile(here, 'square.jpg'));
    %% Prepare background screen
    Screen('Preference','ScreenToHead',0,0,0);
    %Screen('Preference','ScreenToHead',0,1,1);
    Screen('Preference', 'SkipSyncTests', 0);
    screenchosen = Screen('Screens');
    screenNumber = max(screenchosen);
    white = WhiteIndex(screenNumber);
    black = BlackIndex(screenNumber);
    gray = round((white+black)/2);
    if gray == white
        gray = white/2;
    end
    [window,screenRect] = Screen('OpenWindow',screenNumber, black);
    HideCursor;
    [X,Y] = RectCenter(screenRect);
    %X=X+1280;
    dRect = CenterRectOnPointd([0,0,2560,1440],X,Y);
    Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    %% prepare instruction text
    expload = 'MEG Auditory Task';
    rest = 'Take a rest!';
    cue = 'Getting start for next block';
    expend = 'End';
    Screen('TextFont',window,'Ariel');
    Screen('TextSize',window,80);
    DrawFormattedText(window, expload, 'center', 'center', [0 255 0]);
    Screen('Flip',window);
    WaitSecs(2);

    stim = Screen('MakeTexture', window, image);
    deviant = Screen('MakeTexture', window, square);
    ifi = Screen('GetFlipInterval',window);
    slack = ifi/2;
    %% block start
    for blc = 1:block
        block_info = ['Block',num2str(blc),' start'];
        DrawFormattedText(window, block_info, 'center', 'center', [0 255 0]);
        onset=Screen('Flip',window);
        %WaitSecs(2);
        Screen('FillRect',window,[0,255,0], ...
            [CenterRectOnPointd([0,0,20,200],X,Y); ...
            CenterRectOnPointd([0,0,200,20],X,Y)]');
        Screen('Flip',window,onset+2);
        %WaitSecs(1);
        [~, ~, keyCode] = KbCheck;
        if keyCode(escKey)
            running = 0;
            break;
        end
        gaps=zeros(length(total),3);
        for i = 1:length(total)
            if keyCode(escKey)
                running = 0;
                break;
            end
            cnt = cnt + 1;
            ISI=unifrnd(0.1,0.2);%time for pressing key
            if total(i) > 1E7
                % deviant -- 3
                Screen('DrawTexture', window, deviant,[],dRect);
                PsychPortAudio('FillBuffer', pahandle1, [myBeep2; myBeep2]);
                t1=GetSecs;
                tonset=PredictVisualOnsetForTime(window,t1); 
                PsychPortAudio('Start',pahandle1,1,tonset+ifi*1,0);     % 开始播放
                onset = Screen('Flip',window,tonset+ifi*0.5);   
                [nwritten, when]=IOPort('Write',handle,uint8(255)); % 下发类型为1的trigger     
                starttime=onset;
                ResTime(cnt,1) = 2;
                gaps(cnt,1)=tonset-t1;
                gaps(cnt,2)=onset-tonset;
                %gaps(cnt,3)=starttime-tonset;
%                 disp(onset-when);
%                 disp(starttime-when);
%               waitForEndOfPlayback=1;%the function will stop until the end of sound
%                 [starttime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle1, waitForEndOfPlayback);%
%                 IOPort('Write',handle,uint8(0)); 
                while GetSecs-starttime<ISI
                    [KeyIsDown, ~, keyCode] = KbCheck;
                    if KeyIsDown && keyCode(KbName('1!'))
                       ResTime(cnt,2) = GetSecs-starttime;
                       ResTime(cnt,3) = 1;
                    end
                end
                if keyCode(escKey)
                    running = 0;
                    break;
                end

            elseif total(i) < 1E7
                % standard -- 2
                Screen('DrawTexture', window, stim,[],dRect);
                PsychPortAudio('FillBuffer', pahandle1, [myBeep1; myBeep1]);
                t1=GetSecs;
                tonset=PredictVisualOnsetForTime(window,t1);
                PsychPortAudio('Start',pahandle1,1,tonset+ifi*1,0);     % 开始播放
                onset = Screen('Flip',window,tonset+ifi*0.5);
                [nwritten, when]=IOPort('Write',handle,uint8(255)); % 下发类型为1的trigger
                starttime=onset;
                ResTime(cnt,1) = 1;
                ResTime(cnt,3) = 1;
                gaps(cnt,1)=tonset-t1;
                gaps(cnt,2)=onset-tonset;
                %gaps(cnt,3)=starttime-tonset;
%                 disp(onset-when);
%                 disp(starttime-when);
%                 waitForEndOfPlayback=1;
%                 [starttime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle1, waitForEndOfPlayback);%
%                 IOPort('Write',handle,uint8(0)); 
                while GetSecs-starttime<ISI
                    [KeyIsDown, ~, keyCode] = KbCheck;
                    if KeyIsDown && keyCode(KbName('1!'))
                       ResTime(cnt,2) = GetSecs-starttime;
                       ResTime(cnt,3) = 0;
                    end
                end
                if keyCode(escKey)
                    running = 0;
                    break;
                end
            end
            Screen('FillRect', window, [0,255,0], ...
            [CenterRectOnPointd([0,0,20,200], X, Y); ...
            CenterRectOnPointd([0,0,200,20], X, Y)]');
            %Screen('FillRect', window,black, dRect);
            onset = Screen('Flip',window);
            IOPort('Write',handle,uint8(0));
            %onset=Screen('Flip',window);
            ISI = unifrnd(0.1,0.15)-duration_image;
            onset=Screen('Flip',window,onset+ISI-slack);
        
            [KeyIsDown, ~, keyCode] = KbCheck;
            if keyCode(escKey)
                running = 0;
                break;
            end
        end
        
            
        if running  == 0
            break;
        end
        if blc~=block
            DrawFormattedText(window,rest, 'center', 'center', [0 255 0]);
            Screen('Flip',window);
            WaitSecs(10);
            DrawFormattedText(window, cue, 'center', 'center', [0 255 0]);
            Screen('Flip',window);
            WaitSecs(2);
        end
    end
    disp(mean(gaps(:,2)));
    disp(std(gaps(:,2)));
    DrawFormattedText(window, expend, 'center', 'center',[0 255 0]);
    Screen('Flip',window);
    WaitSecs(2);
    IOPort('Close',handle);
    Priority(0);
    Screen('CloseAll');
             PsychPortAudio('Close');
    ShowCursor;

catch
    IOPort('Close',handle);
    Priority(0);
    Screen('CloseAll');
    PsychPortAudio('Close');
    ShowCursor;
end

