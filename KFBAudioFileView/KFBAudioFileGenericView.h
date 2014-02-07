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

/**
 * Abstract superclass of the audio file views, responsible for opening and converting
 * audio data for display by subclasses.
 */
@interface KFBAudioFileGenericView : NSView {
    // A handle to the audio file
    ExtAudioFileRef audioFile;
    
    // The ratio of source file sample rate to internal format sample rate
    float sampleRateRatio;
    
    // The sample data of the file, converted to the internal format
    float *audioData;
    
    // The size of the audio data
    uint32_t audioDataSize;
    
    // The number of samples in the audioData array (which should always be audioDataSize / sizeof(float))
    uint32_t numSamples;
}

/**
 * Loads an audio file from the given URL. Any necessary conversion will be performed
 * and the sample data will be placed into a the view's memory.
 *
 * @param fileURL An NSURL pointing to a valid audio file.
 *
 * @param error An NSError object that will be set on error.
 *
 * @return true if the file was successfully loaded. If the file could not be loaded,
 *         the method will return false and an appropriate NSError object will be
 *         assigned to "error", should a pointer be provied.
 */
- (BOOL)setAudioFile:(NSURL *)fileURL withError:(NSError **)error;

@end
