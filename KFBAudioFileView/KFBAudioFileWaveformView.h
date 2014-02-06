//
//  KFBAudioFileWaveformView.h
//  KFBAudioFileView
//
//  Created by KFB on 09/01/14.
//  Copyright (c) 2014 KFB. All rights reserved.
//

#import "KFBAudioFileGenericView.h"

/** The waveform view can bin audio according to a variety of strategies. */
typedef enum {
    /** 
     * A simple strategy that takes the maximum absolute value each bin. Note that
     * negative values will be made positive!
     */
    kKFBBinStrategy_Abs,
} KFBBinStrategy;

/**
 * A custom NSView to display audio data as a waveform. Various options are provided
 * to control the way that audio data is displayed.
 */
@interface KFBAudioFileWaveformView : KFBAudioFileGenericView {
    // The audio data split into bins
    float *binnedAudio;
}

/** The number of bins */
@property uint32_t binCount;

/**
 * Iniitialises and returns a new waveform view with a given bin count. A count of
 * zero is forbidden and will be clamped to the width (in pixels) of the view.
 *
 * @param frameRect The frame rectangle for the created view object.
 *
 * @param count Number of audio bins. Setting this parameter to zero will result in
 *              a number of bins equivalent to the width in pixels of the view.
 *
 * @return An initialized KFBAudioFileWaveformView object or nil if the object
 *         couldn't be created.
 */
- (id)initWithFrame:(NSRect)frameRect binCount:(uint32_t)count;

/**
 * Prepares the audio data for display by splitting the data into a given number of
 * audio "bins". The audio is binned into the given number of bins according to the
 * specified binning strategy.
 *
 * @param strategy Binning strategy, @see KFBBinStrategy.
 *
 * @param error An NSError object that will be assigned in case of error.
 *
 * @return true if the operation was successful. On failure, returns false and
 *         updates the "error" parameter if a valid object was passed.
 */
- (BOOL)binAudioDataWithStrategy:(KFBBinStrategy)strategy error:(NSError **)error;

@end
