//
//  KFBAudioFileWaveformView.m
//  KFBAudioFileView
//
//  Created by KFB on 09/01/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import "KFBAudioFileWaveformView.h"

@implementation KFBAudioFileWaveformView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)dealloc
{
    // Free the binned audio array
    free(binnedAudio);
}

- (BOOL)splitAudioDataIntoNumberOfBins:(uint32_t)binCount usingStrategy:(KFBBinStrategy)strategy withError:(NSError **)error
{
    // TODO: 'strategy' currently ignored
    
    // Calculate the size of each bin
    uint32_t binSize = audioDataSize / binCount;
    
    // If there's an existing binned audio array, free it
    if (binnedAudio)
    {
        NSLog(@"Freeing previous binned audio array");
        
        free(binnedAudio);
    }
    
    // Allocate the binned audio array
    binnedAudio = malloc(sizeof(float) * binCount);
    
    if (!binnedAudio)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
        }
        
        NSLog(@"Couldn't allocate memory for binned audio array");
        
        return false;
    }
    
    // Loop over the audio data, extracting just maximum absolute value
    for (uint32_t i = 0; i < binCount; i++)
    {
        uint32_t binStart = i * binSize;
        uint32_t binEnd   = binStart + binSize;
        
        // Make sure we don't overflow
        if (binEnd > audioDataSize)
        {
            binEnd = audioDataSize;
        }
        
        // Extract the max value from abs(sample value)
        float maxValue = 0.0f;
        
        for (uint32_t j = binStart; j < binEnd; j++)
        {
            if (j == 12042240) { NSLog(@"audioData[%u] = %f", j, audioData[j]); }
            
            if (fabsf(audioData[j]) > maxValue)
            {
                maxValue = audioData[j];
            }
        }
        
        binnedAudio[i] = maxValue;
        
        NSLog(@"Binned sample %u to %u with value %f", binStart, binEnd, maxValue);
    }
    
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
    
    [[NSColor clearColor] setFill];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
