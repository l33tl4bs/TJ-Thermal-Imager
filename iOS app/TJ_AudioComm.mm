
/*
 
   TJ_AudioComm.mm
 
   TJ_Audiocomm handles the audio-based communication between the TJ hardware and TJ app. including decoding of thermal data
 
 
   Copyright (c) 2014 Marius Popescu
   Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 
   The following code is a derivative work of 'AudioController.m', part of Apple's aurioTouch sample project
 
   'TJ_AudioComm.mm' is part of the TJ app.
 
   TJ app. is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
 
   TJ app. is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
 
   You should have received a copy of the GNU General Public License
   along with TJ app.  If not, see <http://www.gnu.org/licenses/>.
 
 */



#import "TJ_AudioComm.h"

// Framework includes
#import <AVFoundation/AVAudioSession.h>

// Utility file includes
#import "CAXException.h"
#import "CAStreamBasicDescription.h"

@interface TJ_AudioComm()

- (void)setupAudioSession;
- (void)setupIOUnit;
- (void)setupAudioChain;

@end

@implementation TJ_AudioComm


struct CallbackData {
    AudioUnit               rioUnit;
    BOOL*                   audioChainIsBeingReconstructed;
    
    CallbackData(): rioUnit(NULL), audioChainIsBeingReconstructed(NULL) {}
} cd;

// Render callback function
static OSStatus	performRender (void                         *inRefCon,
                               AudioUnitRenderActionFlags 	*ioActionFlags,
                               const AudioTimeStamp 		*inTimeStamp,
                               UInt32 						inBusNumber,
                               UInt32 						inNumberFrames,
                               AudioBufferList              *ioData)
{
    OSStatus err = noErr;
    if (*cd.audioChainIsBeingReconstructed == NO)
    {
        // we are calling AudioUnitRender on the input bus of AURemoteIO
        // this will store the audio data captured by the microphone in ioData
        err = AudioUnitRender(cd.rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
        
        
        SInt16* inbuffer = (SInt16*)(ioData->mBuffers[0].mData);
        static int diff = 0, top, bot;
        static int amp, ex_amp;
        
        static UInt16 byte = 0;
        
        static BOOL low = TRUE;
        
        static UInt16 ex_read_byte = 0, bit_count = 0, read_byte, diffs[8],dif_cnt = 0, sync_cnt = 0,idx = 0;
        static BOOL valid_data = 0;
                
        static UInt16 chksum;
        
        static UInt8 format;
        
        static UInt16 frame_buffer[261];

         for (UInt16 i=0; i<inNumberFrames; i++)
         {

     
             amp = inbuffer[i]; // amplitude of current sample
             //printf("\n%i", amp);
             
             
            if (amp > ex_amp)
            {
                if (low) // this is a rising edge
                {
                    diff = top + bot; // calculate the absolute difference from the top to the bottom of the last falling edge
                    //printf("\n%i", diff);


                    
                    static UInt16 ds0 = 5000,
                                  d01 = 13503,
                                  d12 = 23000,
                                  d23 = 35000;
                    
                    if  (diff < ds0) // this is a SYNC symbol
                    {
                        
                        if (bit_count == 7) // we have read 7 symbol-blocks (a whole data-packet)
                        {
                            read_byte = byte;
                            
                            
                            if (sync_cnt > 14) // this may be the start of a new data-frame (if we receive valid data afterwards)
                            {
                                idx = 0;
                                chksum = 0;
                                
                                if ((1000 <diffs[0]) && (diffs[0] < 6000)) // recalibrate the symbol thresholds from the 1st byte of the data-frame which is a calibration data-packet (SYNC SYMBOL0 SYMBOL1 SYMBOL2 SYMBOL3 SYMBOL2 SYMBOL1)
                                {
                                    ds0 = (diffs[0] + diffs[1]) / 2;
                                    d01 = (diffs[1] + diffs[2]) / 2;
                                    d12 = (diffs[2] + diffs[3]) / 2;
                                    d23 = (diffs[3] + diffs[4]) / 2;
                                }
                            }
                            

                            UInt16 temp = read_byte;
                            
                            if (idx != 1)
                            {
                                // reverse bits order as the thermal data that the D6T-1616L produces is sent LSB 1st
                                UInt8 bl = (temp >> 4);
                                bl = ((bl * 0x0802LU & 0x22110LU) | (bl * 0x8020LU & 0x88440LU)) * 0x10101LU >> 16;
                            
                                UInt8 bh = (temp & 0x0F);
                                bh = ((bh * 0x0802LU & 0x22110LU) | (bh * 0x8020LU & 0x88440LU)) * 0x10101LU >> 16;
                                bh = bh >> 4;
                            
                                temp = (bh << 8) | bl;
                            }
                            else
                                format = temp; // format data-packet needs no bit reversing
                            
                            frame_buffer[idx] = temp;
                            
                            if (idx != 262)
                            {
                                if (idx != 0)
                                    chksum = (chksum + read_byte) & 0xFFF; // compute the 12-bit checksum for the whole data-frame (to match with the checksum embedded in the data-frame the checksum must be calculated using the non-reseversed data-packets)

                                printf("\n%i ", temp);
                                
                                //printf(" | %i |", bit_count);
                                //for (int j=0; j<bit_count; j++)
                                //    printf(" %i ",diffs[j]);
                            }
                            else
                                printf("\n%i ", read_byte);
                            
                            idx++;
                            
                            ex_read_byte = read_byte;
                        }


                        
                        byte = 0;
                        bit_count = 1;
                        dif_cnt = 0;
                        
                        if (valid_data)
                        {
                            valid_data = 0;
                            sync_cnt = 1;
                        }
                        else
                        {
                            sync_cnt++;
                        }
                        
                        if (sync_cnt == 14) // this is the end of a data-frame
                        {
                            printf ("\n len = %i", idx);
                            printf ("\n chksum = %i", chksum);
                             if (read_byte != chksum)
                                 printf("       MISMATCH!");
                             else if (idx == 263)
                             {
                                 printf(" OK"); // checksum correct; data-frame length correct
                                
                                 for (int i = 6; i < 262; i++)
                                 {
                                     float temp = 1;
                                     
                                     if (format == 192) // thermal data stored as 1 sign bit, 9 integer bits, 2 decimal bits
                                     {

                                        if (frame_buffer[i] & 0b100000000000) // if value is negative
                                        {
                                            temp = -1;
                                            frame_buffer[i] &=  0b011111111111;
                                            frame_buffer[i] +=1;
                                        }
                                        else
                                            temp = 1;
                                         
                                        temp = temp * (frame_buffer[i]) / 4;
                                     }
                                     
                                     else if (format == 93) // thermal data stored as 9 integer bits, 3 decimal bits
                                        temp = temp * (frame_buffer[i]) / 8;
                                     
                                     else if (format == 183) // thermal data stored as 1 sign bit, 8 integer bits, 3 decimal bits
                                     {
                                         if (frame_buffer[i] & 0b100000000000) // if value is negative
                                         {
                                             temp = -1;
                                             frame_buffer[i] &=  0b011111111111;
                                             frame_buffer[i] +=1;
                                         }
                                         else
                                             temp = 1;
                                         temp = temp * (frame_buffer[i]) / 8;
                                     }
                                     
                                     else if (format == 84) // thermal data stored as 8 integer bits, 4 decimal bits

                                         temp = temp * (frame_buffer[i]) / 16;
                                     
                                     else if (format == 174) // thermal data stored as 1 sign bit, 7 integer bits, 4 decimal bits
                                     {
                                         if (frame_buffer[i] & 0b100000000000) // if value is negative
                                         {
                                             temp = -1;
                                             frame_buffer[i] &=  0b011111111111;
                                             frame_buffer[i] +=1;
                                         }
                                         else
                                             temp = 1;
                                         temp = temp * (frame_buffer[i]) / 16;
                                     }
                                     
                                     else // thermal data stored as 7 integer bits, 5 decimal bits
                                         temp = temp * (frame_buffer[i]) / 32;
                                     
                                     [[TJ_GLview sharedInstance].IRarray replaceObjectAtIndex:i-6 withObject:[NSNumber numberWithFloat: temp]]; // populate the IRarray with pixel data
                                 }
                                 
                                 [TJ_GLview sharedInstance].ir_new_frame = TRUE;
                                
                             }
                            printf("\n FRAME SYNC");
                        }
                        
                        diffs[dif_cnt] = diff;
                        dif_cnt = (dif_cnt+1) % 8;
                    }
                    else if ((ds0 < diff) && (diff < d01)) // this is a SYMBOL0
                    {
                        valid_data = 1;
        
                        byte = (byte << 2) + 0; // append the 2bit value correspoding to the symbol
                        bit_count++;
                        diffs[dif_cnt] = diff;
                        dif_cnt = (dif_cnt+1) % 8;
                        
                        int lo_lim = ds0 , hi_lim = d01;
                        
                        if ((diff - lo_lim) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i LOW", lo_lim, diff);  // detect amplitude differences that are dangerously close to the thresholds
                        else if ((hi_lim - diff) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i HIGH", diff, hi_lim);
                    }
                    else if ((d01 < diff) && (diff < d12)) // this is a SYMBOL1
                    {
                        valid_data = 1;
                        
                        byte = (byte << 2) + 1; // append the 2bit value correspoding to the symbol
                        bit_count++;
                        diffs[dif_cnt] = diff;
                        dif_cnt = (dif_cnt+1) % 8;
                        
                        int lo_lim = d01 , hi_lim = d12;
                        
                        if ((diff - lo_lim) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i LOW", lo_lim, diff);  // detect amplitude differences that are dangerously close to the thresholds
                        else if ((hi_lim - diff) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i HIGH", diff, hi_lim);
                    }
                    else if ((d12 < diff) && (diff < d23)) // this is a SYMBOL2
                    {
                        valid_data = 1;
                        
                        byte = (byte << 2) + 2; // append the 2bit value correspoding to the symbol
                        bit_count++;
                        diffs[dif_cnt] = diff;
                        dif_cnt = (dif_cnt+1) % 8;
                        
                        int lo_lim = d12 , hi_lim = d23;
                        
                        if ((diff - lo_lim) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i LOW", lo_lim, diff);  // detect amplitude differences that are dangerously close to the thresholds
                        else if ((hi_lim - diff) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i HIGH", diff, hi_lim);
                    }
                    else if (diff > d23) // this is a SYMBOL3
                    {
                        valid_data = 1;
                        
                        byte = (byte << 2) + 3; // append the 2bit value correspoding to the symbol
                        bit_count++;
                        diffs[dif_cnt] = diff;
                        dif_cnt = (dif_cnt+1) % 8;
                        
                        int lo_lim = d23;
                        
                        if ((diff - lo_lim) < 100)
                            printf(" \n TIGHT TOLERANCE  %i | %i LOW", lo_lim, diff);  // detect amplitude differences that are dangerously close to the thresholds
                    }
                    
                }

                top = abs(amp); // this may be the top of the rising edge (if no higher amplitudes are detected after this)

                low = FALSE;
            }
            else if (amp < ex_amp)
            {
                bot = abs(amp); // this may be the bottom of the falling edge (if no lower amplitudes are detected after this
                low = TRUE;
            }
             
            ex_amp = amp;
             
              
         }
        
        //printf("\n new frame");
        
        
        SInt16 values[inNumberFrames],
               values2[inNumberFrames];
        
        static SInt16 lastvalue = -1;
        
            // form two 16000 Hz sine waves phase-shifted 180 degrees
            for (UInt32 i=0; i<inNumberFrames; i++)
            {
                if (lastvalue == -32767)
                {
                    values[i] = 0;
                    values2[i] = 0;
                }
                else if (lastvalue == 0)
                {
                    values[i] = 32767;
                    values2[i] = -32767;
                }
                else
                {
                    values[i] = -32767;
                    values2[i] = 32767;
                }
                
                lastvalue = values[i];
            }
            
            // output the sine waves on the left and right audio channels
            memcpy(ioData->mBuffers[0].mData, values, ioData->mBuffers[0].mDataByteSize);
            memcpy(ioData->mBuffers[1].mData, values2, ioData->mBuffers[1].mDataByteSize);

    }
    
    return err;
}



- (id)init
{
    if (self = [super init]) {
        [self setupAudioChain];
    }
    return self;
}


- (void)handleInterruption:(NSNotification *)notification
{
    try {
        UInt8 theInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] intValue];
        NSLog(@"Session interrupted > --- %s ---\n", theInterruptionType == AVAudioSessionInterruptionTypeBegan ? "Begin Interruption" : "End Interruption");
        
        if (theInterruptionType == AVAudioSessionInterruptionTypeBegan) {
            [self stopIOUnit];
        }
        
        if (theInterruptionType == AVAudioSessionInterruptionTypeEnded) {
            // make sure to activate the session
            NSError *error = nil;
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
            if (nil != error) NSLog(@"AVAudioSession set active failed with error: %@", error);
            
            [self startIOUnit];
        }
    } catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
    }
}


- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] intValue];
    AVAudioSessionRouteDescription *routeDescription = [notification.userInfo valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
    NSLog(@"Route change:");
    switch (reasonValue) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"     NewDeviceAvailable");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"     OldDeviceUnavailable");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"     CategoryChange");
            NSLog(@" New Category: %@", [[AVAudioSession sharedInstance] category]);
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"     Override");
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"     WakeFromSleep");
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"     NoSuitableRouteForCategory");
            break;
        default:
            NSLog(@"     ReasonUnknown");
    }
    
    NSLog(@"Previous route:\n");
    NSLog(@"%@", routeDescription);
}

- (void)handleMediaServerReset:(NSNotification *)notification
{
    NSLog(@"Media server has reset");
    _audioChainIsBeingReconstructed = YES;
    
    usleep(25000); //wait here for some time to ensure that we don't delete these objects while they are being accessed elsewhere
    
    [self setupAudioChain];
    [self startIOUnit];
    
    _audioChainIsBeingReconstructed = NO;
}

- (void)setupAudioSession
{
    try {
        // Configure the audio session
        AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
        

         
        // we are going to play and record so we pick that category
        NSError *error = nil;
        [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
        XThrowIfError((OSStatus)error.code, "couldn't set session's audio category");
        
        // has to be placed after setCategory
        [sessionInstance setMode:AVAudioSessionModeMeasurement
                           error:nil];
        NSLog(@"mode:%@",sessionInstance.mode);
        

        
        // set the buffer duration to 5 ms
        NSTimeInterval bufferDuration = .005; // was 0.005
        [sessionInstance setPreferredIOBufferDuration:bufferDuration error:&error];
        XThrowIfError((OSStatus)error.code, "couldn't set session's I/O buffer duration");
        
        // set the session's sample rate
        [sessionInstance setPreferredSampleRate:48000 error:&error];
        XThrowIfError((OSStatus)error.code, "couldn't set session's preferred sample rate");
        
        // add interruption handler
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:sessionInstance];
        
        // we don't do anything special in the route change notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:sessionInstance];
        
        // if media services are reset, we need to rebuild our audio chain
        [[NSNotificationCenter defaultCenter]	addObserver:	self
                                                 selector:	@selector(handleMediaServerReset:)
                                                     name:	AVAudioSessionMediaServicesWereResetNotification
                                                   object:	sessionInstance];
    
        // activate the audio session
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        XThrowIfError((OSStatus)error.code, "couldn't set session active");
        
        CGFloat gain = 0.0;
        if (sessionInstance.isInputGainSettable) {
            BOOL success = [sessionInstance setInputGain:gain
                                                   error:&error];
            if (!success){} //error handling
        } else {
            NSLog(@"ios6 - cannot set input gain");
        }
    }
    
    catch (CAXException &e) {
        NSLog(@"Error returned from setupAudioSession: %d: %s", (int)e.mError, e.mOperation);
    }
    catch (...) {
        NSLog(@"Unknown error returned from setupAudioSession");
    }
    
    return;
}


- (void)setupIOUnit
{
    try {
        // Create a new instance of AURemoteIO
        
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        XThrowIfError(AudioComponentInstanceNew(comp, &_rioUnit), "couldn't create a new instance of AURemoteIO");
        
        //  Enable input and output on AURemoteIO
        //  Input is enabled on the input scope of the input element
        //  Output is enabled on the output scope of the output element
        
        UInt32 one = 1;
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one)), "could not enable input on AURemoteIO");
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &one, sizeof(one)), "could not enable output on AURemoteIO");
        
        // Explicitly set the input and output client formats
        // sample rate = 44100, num channels = 1, format = 32 bit floating point
        
        CAStreamBasicDescription ioFormat = CAStreamBasicDescription(48000, 2, CAStreamBasicDescription::kPCMFormatInt16, false);
        
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &ioFormat, sizeof(ioFormat)), "couldn't set the input client format on AURemoteIO");
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &ioFormat, sizeof(ioFormat)), "couldn't set the output client format on AURemoteIO");
        
        // Set the MaximumFramesPerSlice property. This property is used to describe to an audio unit the maximum number
        // of samples it will be asked to produce on any single given call to AudioUnitRender
        UInt32 maxFramesPerSlice = 4096;
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(UInt32)), "couldn't set max frames per slice on AURemoteIO");
        
        // Get the property value back from AURemoteIO. We are going to use this value to allocate buffers accordingly
        UInt32 propSize = sizeof(UInt32);
        XThrowIfError(AudioUnitGetProperty(_rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, &propSize), "couldn't get max frames per slice on AURemoteIO");
        
        
        // We need references to certain data in the render callback
        // This simple struct is used to hold that information
        
        cd.rioUnit = _rioUnit;
        cd.audioChainIsBeingReconstructed = &_audioChainIsBeingReconstructed;
        
        // Set the render callback on AURemoteIO
        AURenderCallbackStruct renderCallback;
        renderCallback.inputProc = performRender;
        renderCallback.inputProcRefCon = NULL;
        XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallback, sizeof(renderCallback)), "couldn't set render callback on AURemoteIO");
        
        // Initialize the AURemoteIO instance
        XThrowIfError(AudioUnitInitialize(_rioUnit), "couldn't initialize AURemoteIO instance");
    }
    
    catch (CAXException &e) {
        NSLog(@"Error returned from setupIOUnit: %d: %s", (int)e.mError, e.mOperation);
    }
    catch (...) {
        NSLog(@"Unknown error returned from setupIOUnit");
    }
    
    return;
}


- (void)setupAudioChain
{
    [self setupAudioSession];
    [self setupIOUnit];
}

- (OSStatus)startIOUnit
{
    OSStatus err = AudioOutputUnitStart(_rioUnit);
    if (err) NSLog(@"couldn't start AURemoteIO: %d", (int)err);
    return err;
}

- (OSStatus)stopIOUnit
{
    OSStatus err = AudioOutputUnitStop(_rioUnit);
    if (err) NSLog(@"couldn't stop AURemoteIO: %d", (int)err);
    return err;
}

- (double)sessionSampleRate
{
    return [[AVAudioSession sharedInstance] sampleRate];
}



- (BOOL)audioChainIsBeingReconstructed
{
    return _audioChainIsBeingReconstructed;
}

- (void)dealloc
{
    [super dealloc];
}

@end
