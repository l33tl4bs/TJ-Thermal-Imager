/*
 
   TJ_AudioComm.h
 
   Copyright (c) 2014 Marius Popescu
   Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 
   The following code is a derivative work of 'AudioController.h', part of Apple's aurioTouch sample project
 
   'TJ_AudioComm.h' is part of the TJ app.
 
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
 

 
 

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "TJ_GLview.h"


@interface TJ_AudioComm : NSObject {
    
    AudioUnit               _rioUnit;
    BOOL                    _audioChainIsBeingReconstructed;
}


- (OSStatus)    startIOUnit;
- (OSStatus)    stopIOUnit;
- (double)      sessionSampleRate;

@end
