//
//  KFBAudioFileGenericView.m
//  KFBAudioFileView
//
//  Created by KFB on 09/01/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import "KFBAudioFileGenericView.h"

// Target file audio format properties
static float    kTargetSampleRate       = 96000.0f;
static uint32_t kTargetNumberOfChannels = 2;

@implementation KFBAudioFileGenericView

- (BOOL)isOpaque
{
    return YES;
}

- (void)dealloc
{
    // Dispose of the audio file
    NSLog(@"Disposing of ExtAudioFileRef in -dealloc");
    
    OSStatus status = ExtAudioFileDispose(audioFile);
    
    if (status)
    {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error disposing of ExtAudioFileRef during -dealloc: %@", error);
    }
    
    // Free the sample data
    NSLog(@"Freeing sample data in -dealloc");
    
    free(audioData);
}

- (BOOL)setAudioFile:(NSURL *)fileURL withError:(NSError **)error
{
    NSLog(@"setAudioFile: %@", fileURL);
    
    // If there's an existing ExtAudioFileRef, dispose of it
    if (audioFile)
    {
        NSLog(@"Existing audio file in use, disposing...");
        
        OSStatus status = ExtAudioFileDispose(audioFile);
        
        if (status)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            NSLog(@"Error disposing of previous ExtAudioFileRef: %@", *error);
            
            return false;
        }
    }
    
    // Create an ExtAudioFileRef and store it
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)fileURL, &audioFile);
    
    if (status)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error opening ExtAudioFileRef from %@: %@", fileURL, *error);
        
        return false;
    }
    
    // Convert the file to our internal representation
    if (![self convertAudioFileWithError:error])
    {
        return false;
    }
    
    // Extract the sample data
    if (![self extractSampleDataWithError:error])
    {
        return false;
    }
    
    return true;
}

- (BOOL)convertAudioFileWithError:(NSError **)error
{
    // Convert the audio file's representation to 96KHz/24-bit stereo
    NSLog(@"Converting file representation to internal format");
    
    // Extract the source format description data
    AudioStreamBasicDescription sourceDescription;
    uint32_t sourceDescriptionSize = sizeof(sourceDescription);
    
    OSStatus status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat,
                                              &sourceDescriptionSize, &sourceDescription);
    
    if (status)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error obtaining source file data format: %@", *error);
        
        return false;
    }
    
    // Store the sample rate ratio, we'll be using it later to allocate the
    // sample data array
    sampleRateRatio = kTargetSampleRate / sourceDescription.mSampleRate;
    
    // Print out some info about the source file
    NSLog(@"Source file is as follows:");
    NSLog(@"  mSampleRate       = %f",     sourceDescription.mSampleRate);
    NSLog(@"  mBitsPerChannel   = %u",     sourceDescription.mBitsPerChannel);
    NSLog(@"  mChannelsPerFrame = %u",     sourceDescription.mChannelsPerFrame);
    NSLog(@"  mFormatID         = 0x%08x", sourceDescription.mFormatID);
    NSLog(@"  mFormatFlags      = 0x%08x", sourceDescription.mFormatFlags);
    NSLog(@"  mFramesPerPacket  = %u",     sourceDescription.mFramesPerPacket);
    NSLog(@"  mBytesPerFrame    = %u",     sourceDescription.mBytesPerFrame);
    NSLog(@"  mBytesPerPacket   = %u",     sourceDescription.mBytesPerPacket);
    
    // Setup a target format with the correct specs
    AudioStreamBasicDescription targetDescription;
    uint32_t targetDescriptionSize = sizeof(AudioStreamBasicDescription);
    
    targetDescription.mSampleRate       = kTargetSampleRate;
    targetDescription.mBitsPerChannel   = sizeof(float) * 8;
    targetDescription.mChannelsPerFrame = kTargetNumberOfChannels;
    targetDescription.mFormatID         = kAudioFormatLinearPCM;
    targetDescription.mFormatFlags      = kAudioFormatFlagIsFloat;
    targetDescription.mFramesPerPacket  = 1;
    targetDescription.mBytesPerFrame    = kTargetNumberOfChannels * sizeof(float);
    targetDescription.mBytesPerPacket   = kTargetNumberOfChannels * sizeof(float);
    
    status = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat,
                                     targetDescriptionSize, &targetDescription);
    
    if (status)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error setting target file data format: %@", *error);
        
        return false;
    }
    
    return true;
}

- (BOOL)extractSampleDataWithError:(NSError **)error
{
    // If there's already some sample data, free it
    if (audioData)
    {
        NSLog(@"Releasing existing audio data");
        
        free(audioData);
    }
    
    // Find the length, in frames, of the audio data
    int64_t fileLengthFrames = 0;
    uint32_t fileLengthFramesSize = sizeof(int64_t);
    
    OSStatus status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames,
                                     &fileLengthFramesSize, &fileLengthFrames);
    
    if (status)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error extracting frame count of audio data: %@", *error);
        
        return false;
    }
    
    // Allocate space for our converted sample data
    uint32_t segmentSize;
    
    if (sampleRateRatio < 1.0f)
        segmentSize = fileLengthFrames * kTargetNumberOfChannels / sampleRateRatio;
    else
        segmentSize = fileLengthFrames * kTargetNumberOfChannels * sampleRateRatio;
    
    audioDataSize = sizeof(float) * segmentSize;
    audioData     = malloc(audioDataSize);
    
    if (!audioData)
    {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
        NSLog(@"Couldn't allocate memory for audio data");
        
        return false;
    }
    
    // Set up an AudioBufferList to read the data into
    AudioBufferList audioBufferList;
    
    audioBufferList.mNumberBuffers              = 1;
    audioBufferList.mBuffers[0].mData           = audioData;
    audioBufferList.mBuffers[0].mDataByteSize   = audioDataSize;
    audioBufferList.mBuffers[0].mNumberChannels = kTargetNumberOfChannels;
    
    // Read the data
    // TODO: We can only read 32-bits worth of frames at a time, but potentially have int64_t frames,
    // so we'll need to loop over the data.
    uint32_t framesRead = (uint32_t)fileLengthFrames;
    
    status = ExtAudioFileRead(audioFile, &framesRead, &audioBufferList);
    
    if (status)
    {
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Error reading audio data: %@", *error);
        
        return false;
    }
    
    // Everyone loves some stats--collect them to give us a quick indication that we're reading in
    // samples correctly. There should be approximately the same number of +ve and -ve samples
    uint32_t positiveFrames = 0;
    uint32_t negativeFrames = 0;
    
    float minValue = 0.0f;
    float maxValue = 0.0f;
    
    for (uint32_t i = 0; i < framesRead; i++)
    {
        if (audioData[i] < 0.0f)
        {
            negativeFrames++;
            
            if (audioData[i] < minValue)
            {
                minValue = audioData[i];
            }
        }
        else
        {
            positiveFrames++;
            
            if (audioData[i] > maxValue)
            {
                maxValue = audioData[i];
            }
        }
    }
    
    NSLog(@"%u total frames, %u positive, %u negative", framesRead, positiveFrames, negativeFrames);
    NSLog(@"min value = %f, max value = %f", minValue, maxValue);
    
    return true;
}

//- (void)setAudioFile:(NSURL *)fileURL
//- (void)oldSetAudioFile:(NSURL *)fileURL
//{
//    NSLog(@"setAudioFile:%@", fileURL);
//    
//    // Convert the NSURL to a CFURLRef
//    CFURLRef cfURL = (__bridge CFURLRef)fileURL;
//    
//    // Open the audio file from the URL
//    ExtAudioFileRef extAudioFile = NULL;
//    OSStatus status = ExtAudioFileOpenURL(cfURL, &extAudioFile);
// 
//    if (status)
//    {
//        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
//        NSLog(@"Error when opening file: %@", error);
//        
//        // TODO: something more useful; signal back to the app or throw an exception
//        return;
//    }
//    
//    // Extract information about the file
//    AudioStreamBasicDescription basicDescription;
//    uint32_t basicDescriptionSize = sizeof(AudioStreamBasicDescription);
//    
//    status = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat,
//                                     &basicDescriptionSize, &basicDescription);
//    
//    if (status)
//    {
//        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
//        NSLog(@"Error when reading basic description: %@", error);
//        
//        // TODO: something more useful; signal back to the app or throw an exception
//        return;
//    }
//    
//    NSLog(@"basicDescription.mSampleRate       = %f", basicDescription.mSampleRate);
//    NSLog(@"basicDescription.mChannelsPerFrame = %d", basicDescription.mChannelsPerFrame);
//    NSLog(@"basicDescription.mBitsPerChannel   = %d", basicDescription.mBitsPerChannel);
//    
//    uint32_t numFrames = 0;
//    uint32_t numFramesSize = sizeof(uint64_t);
//    
//    status = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames,
//                                     &numFramesSize, &numFrames);
//    
//    if (status)
//    {
//        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
//        NSLog(@"Error when reading frame count: %@", error);
//        
//        // TODO: something more useful; signal back to the app or throw an exception
//        return;
//    }
//    
//    // Convert the object to 96KHz/24-bit stereo:
//    AudioStreamBasicDescription targetDescription;
//    uint32_t targetDescriptionSize = sizeof(AudioStreamBasicDescription);
//    
//    targetDescription.mSampleRate       = 96000.0f;
//    targetDescription.mBitsPerChannel   = sizeof(float) * 8;
//    targetDescription.mChannelsPerFrame = 2;
//    targetDescription.mFormatID         = kAudioFormatLinearPCM;
//    targetDescription.mFormatFlags      = kAudioFormatFlagIsFloat;
//    targetDescription.mFramesPerPacket  = 1;
//    targetDescription.mBytesPerFrame    = 2 * sizeof(float);
//    targetDescription.mBytesPerPacket   = 2 * sizeof(float);
//    
//    status = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat,
//                                     targetDescriptionSize, &targetDescription);
//    
//    if (status)
//    {
//        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
//        NSLog(@"Error when setting format target: %@", error);
//        
//        // TODO: something more useful; signal back to the app or throw an exception
//        return;
//    }
//
//    // Okay, let's read in the audio data
//    uint32_t sampleDataSize = 2 * 6 * numFrames;
//    
//    float *data = malloc(sampleDataSize * sizeof(float));
//
//    AudioBufferList bufferList;
//    
//    bufferList.mNumberBuffers = 1;
//
//    bufferList.mBuffers[0].mData           = data;
//    bufferList.mBuffers[0].mDataByteSize   = sampleDataSize;
//    bufferList.mBuffers[0].mNumberChannels = 2;
//    
//    status = ExtAudioFileRead(extAudioFile, &numFrames, &bufferList);
//    
//    if (status)
//    {
//        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
//        NSLog(@"Error when reading audio data: %@", error);
//        
//        // TODO: something more useful; signal back to the app or throw an exception
//        return;
//    }
//    
//    NSLog(@"Read %d frames", numFrames);
//    
////    uint32_t numSamplesToDump = 1024;
////    
////    NSLog(@"First %d samples:", numSamplesToDump);
////    
////    for (uint32_t idx = 0; idx < numSamplesToDump; idx++)
////    {
////        if (idx % 8 == 0) { printf("\n"); }
////        
////        printf("%f ", data[idx]);
////    }
////    
////    printf("\n");
//    
//    // Okay, let's bin the audio ready for drawing
//    uint32_t numBins    = 128;
//    uint32_t binSize    = sampleDataSize / numBins;
//    
//    if (overviewData != NULL)
//    {
//        free(overviewData);
//    }
//    
//    overviewDataSize = sizeof(float) * numBins;
//    overviewData = malloc(overviewDataSize);
//    
//    for (uint32_t idx = 0; idx < sampleDataSize; idx += binSize)
//    {
//        overviewData[idx/binSize] = maxBinValue(data, idx, binSize);
//    }
//    
//    NSLog(@"Overview samples:");
//    
//    for (uint32_t idx = 0; idx < numBins; idx++)
//    {
//        if (idx % 8 == 0) { printf("\n"); }
//        
//        printf("%f ", overviewData[idx]);
//    }
//    
//    printf("\n");
//
//    if (audioPoints)
//    {
//        free(audioPoints);
//    }
//    
//    audioPoints = malloc(overviewDataSize);
//    
//    NSLog(@"audioPoints = %p", audioPoints);
//    
//    for (int idx = 0; idx < overviewDataSize; idx++)
//    {
//        audioPoints[idx].x = idx;
//        audioPoints[idx].y = overviewData[idx];
//    }
//    
//    free(data);
//    
//    [self setNeedsDisplay:YES];
//}

@end
