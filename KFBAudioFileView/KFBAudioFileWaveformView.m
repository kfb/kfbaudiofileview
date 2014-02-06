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

- (BOOL)splitAudioDataIntoNumberOfBins:(uint32_t)count usingStrategy:(KFBBinStrategy)strategy withError:(NSError **)error
{
    // TODO: 'strategy' currently ignored
    
    // Store the bin count (we'll use it when drawing the view)
    if (count == 0)
    {
        count = [self bounds].size.width;
    }
    
    binCount = count;
    
    // Calculate the size of each bin
    uint32_t binSize = numSamples / binCount;

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
        if (binEnd > numSamples)
        {
            binEnd = numSamples;
            
            NSLog(@"Adjusting binEnd to numSamples (%i) to avoid overflow", numSamples);
        }
        
        // Extract the max value from abs(sample value)
        float maxValue = 0.0f;
        
        for (uint32_t j = binStart; j < binEnd; j++)
        {
            if (fabsf(audioData[j]) > maxValue)
            {
                maxValue = fabsf(audioData[j]);
            }
        }
        
        binnedAudio[i] = maxValue;
        
        NSLog(@"Binned sample %u to %u with value %f", binStart, binEnd, maxValue);
    }
    
    [self setNeedsDisplay:YES];
    
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Clear the view rectangle
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:dirtyRect];
    
    // Create a bunch of {sampleIndex, value} pairs
    CGPoint audioPoints[binCount];
    
    CGFloat width  = [self bounds].size.width;
    CGFloat height = [self bounds].size.height;
    CGFloat stride = width / binCount;
    
    for (uint32_t i = 0; i < binCount; i++)
    {
        audioPoints[i].x = i * stride;
        audioPoints[i].y = binnedAudio[i];
        
        NSLog(@"Generated audio point {%f, %f}", audioPoints[i].x, audioPoints[i].y);
    }
    
    // With thanks to Chris at SuperMegaUltraGroovy:
    //
    // Build the destination path
    CGMutablePathRef path = CGPathCreateMutable();
    
    // Add a centre line
    CGPoint centreLinePoints[] = {
        {0.0, NSHeight([self bounds]) / 2.0},
        {NSWidth([self bounds]), NSHeight([self bounds]) / 2.0}
    };
    
    CGMutablePathRef centrePath = CGPathCreateMutable();
    CGPathAddLines(centrePath, NULL, centreLinePoints, 2);
    
    // Add the centre line to the destination path
    CGPathAddPath(path, NULL, centrePath);
    
    // Get the overview waveform data (taking into account the level of detail to
    // create the reduced data set)
    CGMutablePathRef halfPath = CGPathCreateMutable();
    CGPathAddLines(halfPath, NULL, audioPoints, binCount);
    
    // Transform to fit the waveform ([0,1] range) into the vertical space
    // ([halfHeight,height] range)
    double halfHeight = floor(height / 2.0);
    
    CGAffineTransform xf = CGAffineTransformIdentity;
    
    xf = CGAffineTransformTranslate(xf, 0.0, halfHeight);
    xf = CGAffineTransformScale(xf, 1.0, halfHeight);
    
    // Add the transformed path to the destination path
    CGPathAddPath( path, &xf, halfPath );
    
    // Transform to fit the waveform ([0,1] range) into the vertical space
    // ([0,halfHeight] range), flipping the Y axis
    xf = CGAffineTransformIdentity;
    
    xf = CGAffineTransformTranslate(xf, 0.0, halfHeight);
    xf = CGAffineTransformScale(xf, 1.0, -halfHeight);
    
    // Add the transformed path to the destination path
    CGPathAddPath(path, &xf, halfPath);
    
    CGPathRelease(halfPath); // clean up!
    
    // Now, path contains the full waveform path.
    CGContextRef cr = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    
    [[NSColor blueColor] set];
    
    CGContextSetLineWidth(cr, 0.5);
    
    CGContextAddPath(cr, path);
    CGContextDrawPath(cr, kCGPathFillStroke);
    
    CGPathRelease(path);
}

@end
