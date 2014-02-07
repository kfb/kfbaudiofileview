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
    return [self initWithFrame:frame binCount:0];
}

- (id)initWithFrame:(NSRect)frameRect binCount:(uint32_t)count
{
    if (self = [super initWithFrame:frameRect])
    {
        // If count is zero, set the number of bins to the width of the view
        if (count == 0) { count = [self bounds].size.width; }
        
        // Store the bin count, we'll use it later in drawRect
        self.binCount = count;
        
        // Allocate space for the binned audio
        binnedAudio = malloc(sizeof(float) * self.binCount);
    }
    
    return self;
}

- (void)dealloc
{
    // Free the binned audio array
    free(binnedAudio);
}

- (float)__processBinWithAbsStrategyAtStartIndex:(uint32_t)binStart endIndex:(uint32_t)binEnd
{
    // Extract the max value from abs(sample value)
    float maxValue = 0.0f;
    
    for (uint32_t j = binStart; j < binEnd; j++)
    {
        if (fabsf(audioData[j]) > maxValue)
        {
            maxValue = fabsf(audioData[j]);
        }
    }
    
    NSLog(@"Binned sample %u to %u with value %f", binStart, binEnd, maxValue);
    
    // Give back the maximum value for the bin
    return maxValue;
}

- (float)__processBinWithAverageStrategyAtStartIndex:(uint32_t)binStart endIndex:(uint32_t)binEnd
{
    float accumulator = 0.0f;
    
    for (uint32_t j = binStart; j < binEnd; j++)
    {
        accumulator += audioData[j];
    }
    
    float result = fabsf((accumulator / (float)(binEnd - binStart)));
    
    NSLog(@"Binned sample %u to %u with value %f", binStart, binEnd, result);
    
    return result;
}

- (float)__processBinUsingStrategy:(KFBBinStrategy)strategy atStartIndex:(uint32_t)binStart endIndex:(uint32_t)binEnd
{
    switch (strategy) {
        case kKFBBinStrategy_Abs:
            return [self __processBinWithAbsStrategyAtStartIndex:binStart endIndex:binEnd];
        
        case kKFBBinStrategy_Average:
            return [self __processBinWithAverageStrategyAtStartIndex:binStart endIndex:binEnd];
            
        default:
            NSLog(@"Unknown KFBBinStrategy: 0x%08x", strategy);
            
            return 0.0;
    }
}

- (void)__binAudioDataWithStrategy:(KFBBinStrategy)strategy
{
    uint32_t binSize = numSamples / self.binCount;
    
    NSBlockOperation *blockOperation = [NSBlockOperation new];
    
    for (uint32_t i = 0; i < self.binCount; i++)
    {
        uint32_t binStart = i * binSize;
        uint32_t binEnd   = binStart + binSize;
        
        // Make sure we don't overflow
        if (binEnd > numSamples)
        {
            binEnd = numSamples;
            
            NSLog(@"Adjusting binEnd to numSamples (%i) to avoid overflow", numSamples);
        }
        
        [blockOperation addExecutionBlock:^{
            binnedAudio[i] = [self __processBinUsingStrategy:strategy atStartIndex:binStart endIndex:binEnd];
        }];
    }
    
    [blockOperation start];
}

- (BOOL)__reallocateBinnedAudioWithError:(NSError **)error
{
    // Allocate (or reallocate if it's already there) the binned audio array
    float *newBinnedAudio = realloc(binnedAudio, sizeof(float) * self.binCount);
    
    // Check if the realloc worked
    if (!newBinnedAudio)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
        }
        
        NSLog(@"Couldn't (re)allocate memory for binned audio array");
        
        return false;
    }
    else
    {
        // It did, so store the new pointer
        binnedAudio = newBinnedAudio;
    }
    
    return true;
}

- (BOOL)binAudioDataWithStrategy:(KFBBinStrategy)strategy error:(NSError **)error
{
    // Try reallocating the binned audio array
    if (![self __reallocateBinnedAudioWithError:error])
    {
        return false;
    }
    
    // Bin the audio and mark the view as needing display
    [self __binAudioDataWithStrategy:strategy];
    [self setNeedsDisplay:YES];
    
    return true;
}

- (void)__generateAudioPoints:(CGPoint *)audioPoints
{
    // Calculate the number of pixels each bin occupies in the view
    CGFloat stride = NSWidth([self bounds]) / self.binCount;
    
    for (uint32_t i = 0; i < self.binCount; i++)
    {
        audioPoints[i].x = i * stride;
        audioPoints[i].y = binnedAudio[i];
        
        NSLog(@"Generated audio point {%f, %f}", audioPoints[i].x, audioPoints[i].y);
    }
}

- (void)__createPathsForAudioPoints:(CGPoint *)audioPoints onDestinationPath:(CGMutablePathRef)path
{
    // With thanks to Chris at SuperMegaUltraGroovy:
    //      http://supermegaultragroovy.com/2009/10/06/drawing-waveforms/
    
    // Add a centre line
    CGPoint centreLinePoints[] = {
        {0.0, NSHeight([self bounds]) / 2.0},
        {NSWidth([self bounds]), NSHeight([self bounds]) / 2.0}
    };
    
    CGMutablePathRef centrePath = CGPathCreateMutable();
    CGPathAddLines(centrePath, NULL, centreLinePoints, 2);
    
    // Add the centre line to the destination path
    CGPathAddPath(path, NULL, centrePath);
    
    // Now clean it up
    CGPathRelease(centrePath);
    
    // Get the overview waveform data (taking into account the level of detail to
    // create the reduced data set)
    CGMutablePathRef halfPath = CGPathCreateMutable();
    CGPathAddLines(halfPath, NULL, audioPoints, self.binCount);
    
    // Transform to fit the waveform ([0,1] range) into the vertical space
    // ([halfHeight,height] range)
    double halfHeight = floor(NSHeight([self bounds]) / 2.0);
    
    CGAffineTransform xf = CGAffineTransformIdentity;
    
    xf = CGAffineTransformTranslate(xf, 0.0, halfHeight);
    xf = CGAffineTransformScale(xf, 1.0, halfHeight);
    
    // Add the transformed path to the destination path
    CGPathAddPath(path, &xf, halfPath);
    
    // Transform to fit the waveform ([0,1] range) into the vertical space
    // ([0,halfHeight] range), flipping the Y axis
    xf = CGAffineTransformIdentity;
    
    xf = CGAffineTransformTranslate(xf, 0.0, halfHeight);
    xf = CGAffineTransformScale(xf, 1.0, -halfHeight);
    
    // Add the transformed path to the destination path
    CGPathAddPath(path, &xf, halfPath);
    
    CGPathRelease(halfPath); // clean up!
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Clear the view rectangle to white
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:dirtyRect];
    
    // Create a bunch of {sampleIndex, value} pairs
    CGPoint audioPoints[self.binCount];
    
    [self __generateAudioPoints:audioPoints];
    
    // Build a CoreGraphics path to draw the waveform
    CGMutablePathRef path = CGPathCreateMutable();
    
    [self __createPathsForAudioPoints:audioPoints onDestinationPath:path];
    
    // Get the graphics context
    CGContextRef cr = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    
    // Draw in blue...
    [[NSColor blueColor] set];
    
    // ...with thinner lines
    CGContextSetLineWidth(cr, 0.5);
    
    // Add the path to the context and draw it!
    CGContextAddPath(cr, path);
    CGContextDrawPath(cr, kCGPathStroke);
    
    // We're done with the path
    CGPathRelease(path);
}

@end
