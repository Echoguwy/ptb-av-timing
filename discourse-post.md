# Draft for Psychtoolbox Discourse

Paste the title and the body below as a new topic. Suggested category: the general or hardware forum, not a help request. Post it after this file is on GitHub, so the image links resolve.

## Title

Light and sound within 0.5 ms on Psychtoolbox: schedule the audio, lock the picture to a frame

## Body

I measure stimulus onset for MEG. A photodiode and a microphone go into an NI cDAQ with the serial trigger, all at 10 kHz. The full note, in Chinese and English, plus two example scripts, is here:

https://github.com/Echoguwy/ptb-av-timing

**What the delay numbers mean.** The trigger is written first, then the stimulus is scheduled. Visual delay then tracks about one refresh: about 50 ms at 60 Hz, about 8–20 ms at 144 Hz, about 5.6 ± 0.05 ms for full-speed black/white at 240 Hz. Flip first and write the trigger afterwards, and the same rig reads about one frame smaller. That is the convention in the Bridges et al. timing mega-study (PeerJ, 2020). I am not claiming a smaller number than that paper. I am using the other clock.

**The rig that stayed stable.** A desktop, an AMD GPU from before 2020 (RX 5700 XT), Ubuntu 20.04, XOrg with Wayland off, `linux-lowlatency`, Psychtoolbox 3.0.21, MATLAB 2020b. Sound in latency class 3 with the buffer left at the device minimum. `SkipSyncTests = 0` has to pass, with no “synchronization trouble” and no “didn’t use pageflipping”. Nvidia’s proprietary driver, hybrid laptops, and Windows did not hold this. On Windows the best I could keep was about 2 ms of wander, and the sync test often failed.

**What actually fixed the jitter.** PTB’s clock is fine when the script names the time. If you do not, it wanders.

Audio only: fill the buffer, then start at an anchor 15 ms in the future, with `waitForStart = 0`.

```matlab
PsychPortAudio('FillBuffer', pahandle, [myBeep; myBeep]);
[nwritten, tonset] = IOPort('Write', handle, uint8(255));
PsychPortAudio('Start', handle, 1, tonset+0.015, 0);
```

Blocking in `Start` (`waitForStart = 1`) and writing the trigger on the next line looks clever, because the trigger then sits on the sound. In my paradigms it was the call that made the rest of the timing fall apart. I do not recommend it.

A picture can change only on a frame. `PredictVisualOnsetForTime` is the anchor, and the audio has to share it. `n+0.5` frames lands mid-interval, so the flip comes out on frame `n+1` instead of slipping to `n+2`. The trigger is written after the flip, so a missed frame cannot walk the trigger-to-image interval.

```matlab
t1 = GetSecs;
tonset = PredictVisualOnsetForTime(window, t1);
PsychPortAudio('Start', pahandle, 1, tonset+delay, 0);
onset = Screen('Flip', window, tonset+(n+0.5)*ifi);
[nwritten, when] = IOPort('Write', handle, uint8(255));
```

An air tube into the shielded room adds about 10 ms, so the sound is the slow one. Push the picture N frames later until the picture is slower, then trim `audioExtraDelay` in steps of about 1 ms. At 144 Hz I sometimes got stuck one frame (about 8 ms) off, because the audio wait had overrun the flip window. Dropping to 60 Hz left enough room to trim. High refresh makes the absolute delay small and the sync fiddly.

**What I measured after that trim.** On a single trial the light edge and the sound edge sit on top of each other, both about 11 ms after the trigger. The sound is a 50 ms tone. The photodiode rises slowly; the edge taken from it still meets the audio onset.

![Single-trial edges](https://raw.githubusercontent.com/Echoguwy/ptb-av-timing/main/assets/fig_av_edges.png)

Across about 260 trials, sound minus light (negative means the sound is slightly early) sits on the 0.1 ms sample grid. The mass is between −0.6 and −0.3 ms, a few points reach −0.1 ms, and the range is about 0.5 ms.

![Trial-by-trial offset](https://raw.githubusercontent.com/Echoguwy/ptb-av-timing/main/assets/fig_av_offset.png)

Auditory delay on its own, once latency class 3 was set, was 29.2 ± 0.1 ms on the 60 Hz rig. Before that it was 49 ± 20 ms.

The repo has two examples. `examples/Image_Sound_Sync` is a still image plus a beep on this schedule. `examples/Video_Sound_Sync` is a 5 Hz half-field checkerboard movie plus a beep; the movies are short H.264 copies of the original uncompressed AVIs.

I would like to know two things. Is `waitForStart = 1` considered safe in current PTB, or is the “do not block the thread” advice still right? And has the Ubuntu 24.04 pageflipping failure (the one a click in the top-right corner used to clear) actually been fixed? My survey of that is about two years old, and I have not moved a lab machine off 20.04.
