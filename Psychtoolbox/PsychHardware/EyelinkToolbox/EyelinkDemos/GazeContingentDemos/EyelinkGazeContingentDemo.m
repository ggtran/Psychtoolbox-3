function EyelinkGazeContingentDemo(mode, ms, myimgfile)
%
% OS X: ___________________________________________________________________
%
% Demo implementation of a generic gaze-contingent display.
% We take one input image and create - via image processing - two images
% out of it: An image to show at the screen location were the subject
% fixates (According to the eye-tracker). A second image to show in the
% peripery of the subjects field of view. These two images are blended into
% each other via a gaussian weight mask (an aperture). The mask is centered
% at the center of gaze and allows for a smooth transition between the two
% images.
%
% This illustrates an application of OpenGL Alpha blending by compositing
% two images based on a spatial gaussian weight mask. Compositing is done
% by the graphics hardware.
%
%
% OS 9 and WINDOWS : ______________________________________________________
%
% GazeContingentDemoOSX does not exist on OS 9 and Windows.
% _________________________________________________________________________
%
% see also: PsychDemosOSX, MovieDemoOSX, DriftDemo

% HISTORY
%
% mm/dd/yy
%
%  7/23/05    mk      Derived it from Frans Cornelissens AlphaImageDemoOSX.
%   29/06/06  fwc     Derived from Mario Kleiner's GazeContingentDemoOSX ;-)

if 1 Screen('Preference', 'SkipSyncTests', 1); end
commandwindow;


% Set hurryup = 1 for benchmarking - Syncing to retrace is disabled
% in that case so we'll get the maximum refresh rate.
hurryup=0;

% Setup default mode to color vs. gray.
if nargin < 1
    mode = 1;
end;

% Setup default aperture size to 2*200 x 2*200 pixels.
if nargin < 2
    ms=200;
end;

% Use default demo images, if no special image was provided.
if nargin < 3
    myimgfile= 'konijntjes1024x768.jpg';
end;

myblurimgfile= 'konijntjes1024x768blur.jpg';
mygrayimgfile= 'konijntjes1024x768gray.jpg';

try
    fprintf('GazeContingentDemo (%s)\n', datestr(now));
    fprintf('Press a key or click on mouse to stop demo.\n');

    % initialize eyelink
    if EyelinkInit()~= 1; %
        return;
    end;



    % This script calls Psychtoolbox commands available only in OpenGL-based
    % versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
    % only OpenGL-based Psychtoolbox.)  The Psychtoolbox command AssertOpenGL will issue
    % an error message if someone tries to execute this script on a computer without
    % an OpenGL Psychtoolbox
    AssertOpenGL;

    % Get the list of screens and choose the one with the highest screen number.
    % Screen 0 is, by definition, the display with the menu bar. Often when
    % two monitors are connected the one without the menu bar is used as
    % the stimulus display.  Chosing the display with the highest display number is
    % a best guess about where you want the stimulus displayed.
    screenNumber=max(Screen('Screens'));

    % Open a double buffered fullscreen window.
    [w, wRect]=Screen('OpenWindow',screenNumber);

    % Find the color values which correspond to white and black.  Though on OS
    % X we currently only support true color and thus, for scalar color
    % arguments,
    % black is always 0 and white 255, this rule is not true on other platforms will
    % not remain true on OS X after we add other color depth modes.
    white=WhiteIndex(screenNumber);
    black=BlackIndex(screenNumber);
    gray=GrayIndex(screenNumber); % returns as default the mean gray value of screen

    % Set background color to gray:
    backgroundcolor = gray;

    % Load image file:
    fprintf('Using image ''%s''\n', myimgfile);
    imdata=imread(myimgfile);
    imdatablur=imread(myblurimgfile);
    imdatagray=imread(mygrayimgfile);

    %     crop image if it is larger then screen size. There's no image scaling
    %     in maketexture
    [iy, ix, id]=size(imdata);
    [wW, wH]=WindowSize(w);
    % wW=wRect(3);
    % wH=wRect(4);
    if ix>wW | iy>wH
        disp('Image size exceeds screen size');
        disp('Image will be cropped');
    end

    if ix>wW
        cl=round((ix-wW)/2);
        cr=(ix-wW)-cl;
    else
        cl=0;
        cr=0;
    end
    if iy>wH
        ct=round((iy-wH)/2);
        cb=(iy-wH)-ct;
    else
        ct=0;
        cb=0;
    end

    % imdata is the cropped version of the image.
    imdata=imdata(1+ct:iy-cb, 1+cl:ix-cr,:);
    imdatablur=imdatablur(1+ct:iy-cb, 1+cl:ix-cr,:);
    imdatagray=imdatagray(1+ct:iy-cb, 1+cl:ix-cr,:);

    % Compute image for foveated region and periphery:
    switch (mode)
        case 1
            % Mode 1:
            % Fovea contains original image data:
            foveaimdata = imdata;
            % Periphery contains grayscale-version:
            peripheryimdata = imdatagray;
        case 2
            % Fovea contains original image data:
            foveaimdata = imdata;
            % Periphery contains blurred-version:
            peripheryimdata = imdatablur;
        case 3
            % Fovea contains color-inverted image data:
            foveaimdata(:,:,:) = 255 - imdata(:,:,:);
            % Periphery contains original data:
            peripheryimdata = imdata;
        case 4
            % Test-case: One shouldn't see any foveated region on the
            % screen - this is a basic correctness test for blending.
            foveaimdata = imdata;
            peripheryimdata = imdata;
        otherwise
            % Unknown mode! We force abortion:
            fprintf('Invalid mode provided!');
            abortthisbeast
    end;

    % Build texture for foveated region:
    foveatex=Screen('MakeTexture', w, foveaimdata);
    tRect=Screen('Rect', foveatex);

    % Build texture for peripheral (non-foveated) region:
    nonfoveatex=Screen('MakeTexture', w, peripheryimdata);
    [ctRect, dx, dy]=CenterRect(tRect, wRect);

    % We create a Luminance+Alpha matrix for use as transparency mask:
    % Layer 1 (Luminance) is filled with 'backgroundcolor'.
    transLayer=2;
    [x,y]=meshgrid(-ms:ms, -ms:ms);
    maskblob=ones(2*ms+1, 2*ms+1, transLayer) * backgroundcolor;
    % Layer 2 (Transparency aka Alpha) is filled with gaussian transparency
    % mask.
    xsd=ms/2.2;
    ysd=ms/2.2;
    maskblob(:,:,transLayer)=round(255 - exp(-((x/xsd).^2)-((y/ysd).^2))*255);

    % Build a single transparency mask texture:
    masktex=Screen('MakeTexture', w, maskblob);
    mRect=Screen('Rect', masktex);

    fprintf('Size image texture: %d x %d\n', RectWidth(tRect), RectHeight(tRect));
    fprintf('Size  mask texture: %d x %d\n', RectWidth(mRect), RectHeight(mRect));


    % Set background color to 'backgroundcolor' and do initial flip to show
    % blank screen:
    Screen('FillRect', w, backgroundcolor);
    Screen('Flip', w);


    % do eyelink stuff
    el=EyelinkInitDefaults(w);

    % make sure that we get gaze data from the Eyelink
    Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');

    % open file to record data to
    Eyelink('openfile', 'demo.edf');

    % STEP 4
    % Calibrate the eye tracker
    EyelinkDoTrackerSetup(el);

    % do a final check of calibration using driftcorrection
    EyelinkDoDriftCorrection(el);

    WaitSecs(0.1);
    Eyelink('StartRecording');

    eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
    if eye_used == el.BINOCULAR; % if both eyes are tracked
        eye_used = el.LEFT_EYE; % use left eye
    end

    % Set background color to 'backgroundcolor' and do initial flip to show
    % blank screen:
    Screen('FillRect', w, backgroundcolor);
    Screen('Flip', w);


    % The mouse-cursor position will define gaze-position (center of
    % fixation) to simulate (x,y) input from an eyetracker. Set cursor
    % initially to center of screen:
    [a,b]=RectCenter(wRect);
    WaitSetMouse(a,b,screenNumber); % set cursor and wait for it to take effect

    HideCursor;
    buttons=0;

    priorityLevel=MaxPriority(w);
    Priority(priorityLevel);

    % Wait until all keys on keyboard are released:
    while KbCheck; WaitSecs(0.1); end;

    mxold=0;
    myold=0;

    oldvbl=Screen('Flip', w);
    tavg = 0;
    ncount = 0;

    % Infinite display loop: Whenever "gaze position" changes, we update
    % the display accordingly. Loop aborts on keyboard press or mouse
    % click or after 10000 frames...
    while (ncount < 10000)


        if 1
            error=Eyelink('CheckRecording');
            if(error~=0)
                break;
            end

            if Eyelink( 'NewFloatSampleAvailable') > 0
                % get the sample in the form of an event structure
                evt = Eyelink( 'NewestFloatSample');
                if eye_used ~= -1 % do we know which eye to use yet?
                    % if we do, get current gaze position from sample
                    x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
                    y = evt.gy(eye_used+1);
                    % do we have valid data and is the pupil visible?
                    if x~=el.MISSING_DATA & y~=el.MISSING_DATA & evt.pa(eye_used+1)>0

                        mx=x;
                        my=y;
                    end
                end
            end
        else

            % Query current mouse cursor position (our "pseudo-eyetracker") -
            % (mx,my) is our gaze position.
            if (hurryup==0)
                [mx, my, buttons]=GetMouse; %(w);
            else
                % In benchmark mode, we just do a quick sinusoidal motion
                % without query of the mouse:
                mx=500 + 500*sin(ncount/10); my=300;
            end;
        end
        % We only redraw if gazepos. has changed:
        if (mx~=mxold | my~=myold)
            % Compute position and size of source- and destinationrect and
            % clip it, if necessary...
            myrect=[mx-ms my-ms mx+ms+1 my+ms+1]; % center dRect on current mouseposition
            dRect = ClipRect(myrect,ctRect);
            sRect=OffsetRect(dRect, -dx, -dy);

            % Valid destination rectangle?
            if ~IsEmptyRect(dRect)
                % Yes! Draw image for current frame:

                % Step 1: Draw the alpha-mask into the backbuffer. It
                % defines the aperture for foveation: The center of gaze
                % has zero alpha value. Alpha values increase with distance from
                % center of gaze according to a gaussian function and
                % approach 255 at the border of the aperture...
                Screen('BlendFunction', w, GL_ONE, GL_ZERO);
                Screen('DrawTexture', w, masktex, [], myrect);

                % Step 2: Draw peripheral image. It is only drawn where
                % the alpha-value in the backbuffer is 255 or high, leaving
                % the foveated area (low or zero alpha values) alone:
                % This is done by weighting each color value of each pixel
                % with the corresponding alpha-value in the backbuffer
                % (GL_DST_ALPHA).
                Screen('BlendFunction', w, GL_DST_ALPHA, GL_ZERO);
                Screen('DrawTexture', w, nonfoveatex, [], ctRect);

                % Step 3: Draw foveated image, but only where the
                % alpha-value in the backbuffer is zero or low: This is
                % done by weighting each color value with one minus the
                % corresponding alpha-value in the backbuffer
                % (GL_ONE_MINUS_DST_ALPHA).
                Screen('BlendFunction', w, GL_ONE_MINUS_DST_ALPHA, GL_ONE);
                Screen('DrawTexture', w, foveatex, sRect, dRect);

                % Show final result on screen. This also clears the drawing
                % surface back to black background color and a zero alpha
                % value.
                % Actually... We use clearmode=2: This doesn't clear the
                % backbuffer, but we don't need to clear it for this kind
                % of stimulus and it gives us 2 msecs extra headroom for
                % higher refresh rates! For benchmark purpose, we disable
                % syncing to retrace if hurryup is == 1.
                vbl = Screen('Flip', w, 0, 2, 2*hurryup);
                vbl = GetSecs;
                tavg = tavg + (vbl-oldvbl);
                oldvbl=vbl;
                ncount = ncount + 1;
            end;
        end;

        % Keep track of last gaze position:
        mxold=mx;
        myold=my;

        % We wait 1 ms each loop-iteration so that we
        % don't overload the system in realtime-priority:
        WaitSecs(0.001);

        % Abort demo on keypress our mouse-click:
        if KbCheck | find(buttons) % break out of loop
            break;
        end;
    end;

    % stop eyelink
    Eyelink('StopRecording');
    Eyelink('ShutDown');



    % Display full image a last time, just for fun...
    Screen('BlendFunction', w, GL_ONE, GL_ZERO);
    Screen('DrawTexture', w, foveatex);
    Screen('Flip', w);
    WaitSecs(1);
    % The same command which closes onscreen and offscreen windows also
    % closes textures.
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    tavg = tavg / ncount * 1000;
    fprintf('End of GazeContingentDemo. Avg. redraw time is %f ms = %f Hz.\n\n', tavg, 1000 / tavg);
    return;
catch
    %this "catch" section executes in case of an error in the "try" section
    %above.  Importantly, it closes the onscreen window if its open.
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    %     psychrethrow(lasterror);
end %try..catch..
