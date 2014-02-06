//
//  KFBAudioFileWaveformView.h
//  KFBAudioFileView
//
//  Created by KFB on 09/01/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import "KFBAudioFileGenericView.h"

typedef enum {
    kKFBBinStrategy_Abs,
} KFBBinStrategy;

@interface KFBAudioFileWaveformView : KFBAudioFileGenericView {
    // The audio data split into bins
    float *binnedAudio;
    
    // The number of bins
    uint32_t binCount;
}

- (BOOL)splitAudioDataIntoNumberOfBins:(uint32_t)count usingStrategy:(KFBBinStrategy)strategy withError:(NSError **)error;

@end
