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
    number_nontarget = 200;
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
    image = imread(fullfile(here, 'checker.jpg'));
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
     
    %% ===== 打开视频文件 =====
    movieFile1 = fullfile(here, 'half_left_checkerboard_5Hz_1080p.mp4');
    movie1 = Screen('OpenMovie', window, movieFile1);
    movieFile2 = fullfile(here, 'half_bottom_checkerboard_5Hz_1080p.mp4');
    movie2 = Screen('OpenMovie', window, movieFile2);
    vr1 = VideoReader(movieFile1);
    movieFPS1 = vr1.FrameRate;
    movieDur1 = vr1.Duration;
    movieNFrames1=vr1.NumFrames;
    
    vr2 = VideoReader(movieFile2);
    movieFPS2 = vr2.FrameRate;
    movieDur1 = vr2.Duration;
    movieNFrames2=vr2.NumFrames;
    if movieFPS1 <= 0, movieFPS1 = 30; end    % 防止个别容器读不到帧率
    fprintf('视频: %.2f s, %.1f fps, %d 帧\n', movieDur1, movieFPS1, movieNFrames1);

    %% ===== 计算每个视频帧应停留的刷新周期数 =====
    ifi        = Screen('GetFlipInterval', window);
    screenFPS  = 1 / ifi;
    holdFrames1 = max(1, round(screenFPS / movieFPS1));   % 60Hz屏幕 -> 每帧停2个刷新
    fprintf('屏幕: %.2f Hz, 每个视频帧停留 %d 个刷新周期\n', screenFPS, holdFrames1);

    
    
    %% prepare instruction text
    expload = 'MEG Video-Audio-Sync Task';
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
            
            %% ===== 启动异步解码（rate=0：手动逐帧取图，播放节奏自己控制）=====
            Screen('SetMovieTimeIndex', movie1, 0, 0);
            Screen('SetMovieTimeIndex', movie2, 0, 0);
            frameCnt=0;
            flipTimes=[];
            if total(i) > 1E7
                % deviant -- 3
                %Screen('DrawTexture', window, deviant,[],dRect);
                [tex, frameIdx] = Screen('GetMovieImage', window, movie1, 1);
                disp(1);
                Screen('DrawTexture', window, tex, [], dRect);%先跑第一帧
                frameCnt = frameCnt + 1;
                PsychPortAudio('FillBuffer', pahandle1, [myBeep2; myBeep2]);
                
                
                t1=GetSecs;
                tonset=PredictVisualOnsetForTime(window,t1); 
                PsychPortAudio('Start',pahandle1,1,tonset+ifi*1+0.02,0);     % 开始播放
                onset = Screen('Flip',window,tonset+ifi*0.5);
                Screen('Close', tex);
                [nwritten, when]=IOPort('Write',handle,uint8(255)); % 下发类型为1的trigger
                
                ResTime(cnt,1) = 2;
                gaps(cnt,1)=tonset-t1;
                gaps(cnt,2)=onset-tonset;
                
                while(true)
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(escKey), fprintf('按ESC手动退出。\n'); break; end

                    % 阻塞等待下一帧解码完成；tex <= 0 表示视频结束
                    [tex, frameIdx] = Screen('GetMovieImage', window, movie1, 1);
                    if tex <= 0
                        fprintf('播放结束，共显示 %d 帧。\n', frameCnt);
                        break;
                    end
                    frameCnt = frameCnt + 1;
                    Screen('DrawTexture', window, tex, [], dRect);
                    onset = Screen('Flip', window,onset+ifi*(holdFrames1-0.5));%持续固定帧（由帧率和刷新率决定）播放下一张图像
                    Screen('Close', tex);
                    flipTimes(end+1, 1) = onset; % ok<AGROW>
                end
                %gaps(cnt,3)=starttime-tonset;
%                 disp(onset-when);
%                 disp(starttime-when);
%               waitForEndOfPlayback=1;%the function will stop until the end of sound
%                 [starttime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle1, waitForEndOfPlayback);%
%                 IOPort('Write',handle,uint8(0)); 
                starttime=onset;
                while GetSecs-starttime<ISI %捕捉按键
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
                %Screen('DrawTexture', window, deviant,[],dRect);
                [tex, frameIdx] = Screen('GetMovieImage', window, movie2, 1);
                Screen('DrawTexture', window, tex, [], dRect);%先跑第一帧
                frameCnt = frameCnt + 1;
                PsychPortAudio('FillBuffer', pahandle1, [myBeep1; myBeep1]);
                
                
                t1=GetSecs;
                tonset=PredictVisualOnsetForTime(window,t1); 
                PsychPortAudio('Start',pahandle1,1,tonset+ifi*1+0.02,0);     % 开始播放
                onset = Screen('Flip',window,tonset+ifi*0.5);
                Screen('Close', tex);
                [nwritten, when]=IOPort('Write',handle,uint8(255)); % 下发类型为1的trigger
                
                ResTime(cnt,1) = 2;
                gaps(cnt,1)=tonset-t1;
                gaps(cnt,2)=onset-tonset;
                
                while(true)
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(escKey), fprintf('按ESC手动退出。\n'); break; end

                    % 阻塞等待下一帧解码完成；tex <= 0 表示视频结束
                    [tex, frameIdx] = Screen('GetMovieImage', window, movie2, 1);
                    if tex <= 0
                        fprintf('播放结束，共显示 %d 帧。\n', frameCnt);
                        break;
                    end
                    frameCnt = frameCnt + 1;
                    Screen('DrawTexture', window, tex, [], dRect);
                    onset = Screen('Flip', window,onset+ifi*(holdFrames1-0.5));%持续固定帧（由帧率和刷新率决定）播放下一张图像
                    Screen('Close', tex);
                    flipTimes(end+1, 1) = onset; % ok<AGROW>

                end
                %gaps(cnt,3)=starttime-tonset;
%                 disp(onset-when);
%                 disp(starttime-when);
%               waitForEndOfPlayback=1;%the function will stop until the end of sound
%                 [starttime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle1, waitForEndOfPlayback);%
%                 IOPort('Write',handle,uint8(0)); 
                starttime=onset;
                while GetSecs-starttime<ISI %捕捉按键
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

catch ME
    IOPort('Close',handle);
    Priority(0);
    Screen('CloseAll');
    PsychPortAudio('Close');
    ShowCursor;
    
    % 输出报错内容
    fprintf(2, '\n===== PTB脚本出错 =====\n');
    fprintf(2, '错误信息: %s\n', ME.message);
    for i = 1:numel(ME.stack)
        fprintf(2, '  位置: %s 第 %d 行 (%s)\n', ...
            ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end

    % 重新抛出，让MATLAB保持完整报错状态（行号可点击跳转）
    psychrethrow(ME);        % 也可以写成 rethrow(ME)
    
end



