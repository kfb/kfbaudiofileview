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
            if (error)
            {
                *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
                
                NSLog(@"Error disposing of previous ExtAudioFileRef: %@", *error);
            }
            
            return false;
        }
    }
    
    // Create an ExtAudioFileRef and store it
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)fileURL, &audioFile);
    
    if (status)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            
            NSLog(@"Error opening ExtAudioFileRef from %@: %@", fileURL, *error);
        }
        
        return false;
    }
    
    // Convert the file to our internal representation
    if (![self __convertAudioFileWithError:error])
    {
        return false;
    }
    
    // Extract the sample data
    if (![self __extractSampleDataWithError:error])
    {
        return false;
    }
    
    return true;
}

- (BOOL)__convertAudioFileWithError:(NSError **)error
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
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            
            NSLog(@"Error obtaining source file data format: %@", *error);
        }
        
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
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            
            NSLog(@"Error setting target file data format: %@", *error);
        }
        
        return false;
    }
    
    return true;
}

- (BOOL)__extractSampleDataWithError:(NSError **)error
{
    // If there's already some sample data, free it
    if (audioData)
    {
        NSLog(@"Releasing existing audio data");
        
        free(audioData);
    }
    
    // Find the length, in frames, of the audio data
    int64_t  fileLengthFrames     = 0;
    uint32_t fileLengthFramesSize = sizeof(int64_t);
    
    OSStatus status = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames,
                                     &fileLengthFramesSize, &fileLengthFrames);
    
    if (status)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            
            NSLog(@"Error extracting frame count of audio data: %@", *error);
        }
        
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
    numSamples    = audioDataSize / sizeof(float);
    
    if (!audioData)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
        }
        
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
        if (error)
        {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            
            NSLog(@"Error reading audio data: %@", *error);
        }
        
        return false;
    }

    return true;
}

@end
