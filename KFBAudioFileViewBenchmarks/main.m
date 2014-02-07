//
//  main.m
//  KFBAudioFileViewBenchmarks
//
//  Created by KFB on 07/02/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KFBAudioFileView.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)];
        
        NSURL   *fileURL = [[NSBundle mainBundle] URLForResource:@"STE-000" withExtension:@"wav"];
        NSError *error;
        
        [waveformView setAudioFile:fileURL withError:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            return -1;
        }
        
        [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Abs error:&error];
        
        if (error)
        {
            NSLog(@"Error: %@", error);
            return -1;
        }
    }
    
    return 0;
}

