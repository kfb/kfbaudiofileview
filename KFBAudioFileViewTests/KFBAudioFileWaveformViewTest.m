//
//  KFBAudioFileWaveformViewTest.m
//  KFBAudioFileView
//
//  Created by KFB on 07/02/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "KFBAudioFileView.h"

@interface KFBAudioFileWaveformViewTest : XCTestCase

@end

@implementation KFBAudioFileWaveformViewTest

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEndToEndPerformance
{
    KFBAudioFileWaveformView *waveformView = [[KFBAudioFileWaveformView alloc] initWithFrame:NSMakeRect(0, 0, 512, 512)];
    
    NSURL   *fileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"STE-000" withExtension:@"wav"];
    NSError *error   = nil;
    
    [waveformView setAudioFile:fileURL withError:&error];

    if (error)
    {
        XCTFail(@"%@", error);
    }

    error = nil;
    
    [waveformView binAudioDataWithStrategy:kKFBBinStrategy_Abs error:&error];
    
    if (error)
    {
        XCTFail(@"%@", error);
    }
}

@end
