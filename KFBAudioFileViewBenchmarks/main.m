//
//  main.m
//  KFBAudioFileViewBenchmarks
//
//  Created by KFB on 07/02/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KFBAudioFileView.h"

void benchmarkSmallBinCountAbsStrategy(void)
{
    @autoreleasepool {
        KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)
                                                                                        binCount:32];
        
        NSURL   *fileURL = [[NSBundle mainBundle] URLForResource:@"STE-000" withExtension:@"wav"];
        NSError *error;
        
        [waveformView setAudioFile:fileURL withError:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
        
        [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Abs error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
    }
}

void benchmarkLargeBinCountAbsStrategy(void)
{
    @autoreleasepool {
        KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)
                                                                                        binCount:8192];
        
        NSURL   *fileURL = [[NSBundle mainBundle] URLForResource:@"STE-000" withExtension:@"wav"];
        NSError *error;
        
        [waveformView setAudioFile:fileURL withError:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
        
        [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Abs error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
    }
}

void benchmarkSmallBinCountAverageStrategy(void)
{
    @autoreleasepool {
        KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)
                                                                                        binCount:32];
        
        NSURL   *fileURL = [[NSBundle mainBundle] URLForResource:@"STE-000" withExtension:@"wav"];
        NSError *error;
        
        [waveformView setAudioFile:fileURL withError:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
        
        [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Average error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
    }
}

void benchmarkLargeBinCountAverageStrategy(void)
{
    @autoreleasepool {
        KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)
                                                                                        binCount:8192];
        
        NSURL   *fileURL = [[NSBundle mainBundle] URLForResource:@"STE-000" withExtension:@"wav"];
        NSError *error;
        
        [waveformView setAudioFile:fileURL withError:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
        
        [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Average error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            
            exit(EXIT_FAILURE);
        }
    }
}

int main(int argc, const char * argv[])
{
    const uint32_t BENCHMARK_ITERATIONS = 1;
    
    @autoreleasepool {
        for (uint32_t i = 0; i < BENCHMARK_ITERATIONS; i++)
        {
            benchmarkSmallBinCountAbsStrategy();
            benchmarkLargeBinCountAbsStrategy();
        }
        
        for (uint32_t i = 0; i < BENCHMARK_ITERATIONS; i++)
        {
            benchmarkSmallBinCountAverageStrategy();
            benchmarkLargeBinCountAverageStrategy();
        }
    }
    
    return 0;
}

