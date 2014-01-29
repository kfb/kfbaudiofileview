//
//  KFBAudioFileGenericView.h
//  KFBAudioFileView
//
//  Created by KFB on 09/01/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//
// Okay, so it should be KFBAudioFileView.h, but that's reserved for exporting the
// view types in the framework.

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

@interface KFBAudioFileGenericView : NSView {
    // A handle to the audio file
    ExtAudioFileRef audioFile;
    
    // The ratio of source file sample rate to internal format sample rate
    float sampleRateRatio;
    
    // The sample data of the file, converted to the internal format
    float *audioData;
    
    // The size of the audio data
    uint32_t audioDataSize;
}

- (BOOL)extractSampleDataWithError:(NSError **)error;
- (BOOL)convertAudioFileWithError:(NSError **)error;
- (BOOL)setAudioFile:(NSURL *)fileURL withError:(NSError **)error;

@end
