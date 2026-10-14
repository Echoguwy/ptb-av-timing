# Psychtoolbox Discourse

Posted: https://psychtoolbox.discourse.group/t/visual-and-auditory-jitter-under-1-ms-light-sound-delay-within-0-5-ms-7-rules-that-held-up/5819

## Title

## Title

Visual and auditory jitter under 1 ms, light and sound within 0.5 ms: 7 rules that held up

## Body

I timestamp MEG stimuli with a photodiode, a microphone, and an NI card at 10 kHz, and I only kept the setups whose trial-to-trial jitter stayed under 1 ms. Absolute delay depends on whether the trigger is written before or after the flip, so I am not quoting those means here. Jitter and light–sound alignment are what matter for averaging. Hardware, the measurement recipe, and two example scripts are in the note:

https://github.com/Echoguwy/ptb-av-timing

**Jitter, after the rules below.** Auditory delay went from ±20 ms to **±0.1 ms**. Visual delay jitter was **±0.1 to ±0.4 ms** at 60 Hz, **±0.2 ms** at 144 Hz, and **±0.05 ms** for full-speed black/white at 240 Hz. Before this, Windows with default settings left the auditory jitter at ±20 ms, which is not usable for averaging.

**Light versus sound.** On a single trial the two rising edges sit on top of each other. Across about 260 trials, sound minus light (negative means the sound is slightly early) lies on the 0.1 ms sample grid, mostly between **−0.6 and −0.3 ms**, with the whole range about **0.5 ms**. The tightest run in the notes was **−0.02 ± 0.08 ms**.

![Single-trial edges](https://raw.githubusercontent.com/Echoguwy/ptb-av-timing/main/assets/fig_av_edges.png)

![Trial-by-trial light–sound offset](https://raw.githubusercontent.com/Echoguwy/ptb-av-timing/main/assets/fig_av_offset.png)

The rig that produced this was a desktop, an AMD GPU from before 2020, Ubuntu 20.04 with XOrg and Wayland off, `linux-lowlatency`, PTB 3.0.21, and MATLAB. `SkipSyncTests = 0` had to pass cleanly. Nvidia proprietary drivers, laptop hybrid graphics, and Windows did not hold the jitter.

Seven rules. Breaking one of them put the jitter back to ±5 ms, sometimes ±50 ms. The long version, with code, is in the repository.

1. **Desktop, discrete AMD GPU, Ubuntu, MATLAB or Octave.** Not a laptop iGPU, not a proprietary Nvidia driver, not Windows for a real session.
2. **Own the sound card, and keep the buffer at the device minimum.** `PsychPortAudio('Open',[],1,3,sf,2,1)`. Only latency class 3 stayed inside 1 ms. Class 1 split into two clusters about 10 ms apart.
3. **One screen owns the GPU, and every screen uses the same resolution and refresh.** In single-screen mode, offset drawing in X by half a screen.
4. **Name the time for audio, and name the frame for the picture.** Fill the audio buffer, then start at a future anchor with `waitForStart = 0`. For a picture, take the anchor from `PredictVisualOnsetForTime` and flip at `tonset+(n+0.5)*ifi`, so the image lands on frame n+1 instead of slipping one more. Audio and picture share that anchor. Write the trigger after the flip, or a missed frame shows up as jitter. Do not block in `Start` (`waitForStart = 1`). It looks precise and it made the rest of the paradigm fall apart.
5. **Warm up.** Run the script once so the mex files are loaded, then do not change folders.
6. **Buttons are a coarser clock.** `KbWait` is about 5 ms. Loop `KbCheck` and read `deltaSecs`, or record the button on the same NI or MEG clock.
7. **Preload video.** `PlayMovie` at the start of the trial, then a blocking `GetMovieImage`. Draw the first frame into the back buffer before scheduling it. Later frames use `onset+ifi*(holdFrames-0.5)`.

I would like to hear whether `waitForStart = 1` is considered safe in current PTB, and whether the Ubuntu 24.04 pageflipping failure is actually fixed. I have not moved a lab machine off 20.04.
