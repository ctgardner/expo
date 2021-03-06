// Copyright 2017-present 650 Industries. All rights reserved.

#import <ReactABI21_0_0/ABI21_0_0RCTUtils.h>

#import "ABI21_0_0EXAVPlayerData.h"

NSString *const ABI21_0_0EXAVPlayerDataStatusIsLoadedKeyPath = @"isLoaded";
NSString *const ABI21_0_0EXAVPlayerDataStatusURIKeyPath = @"uri";
NSString *const ABI21_0_0EXAVPlayerDataStatusProgressUpdateIntervalMillisKeyPath = @"progressUpdateIntervalMillis";
NSString *const ABI21_0_0EXAVPlayerDataStatusDurationMillisKeyPath = @"durationMillis";
NSString *const ABI21_0_0EXAVPlayerDataStatusPositionMillisKeyPath = @"positionMillis";
NSString *const ABI21_0_0EXAVPlayerDataStatusPlayableDurationMillisKeyPath = @"playableDurationMillis";
NSString *const ABI21_0_0EXAVPlayerDataStatusShouldPlayKeyPath = @"shouldPlay";
NSString *const ABI21_0_0EXAVPlayerDataStatusIsPlayingKeyPath = @"isPlaying";
NSString *const ABI21_0_0EXAVPlayerDataStatusIsBufferingKeyPath = @"isBuffering";
NSString *const ABI21_0_0EXAVPlayerDataStatusRateKeyPath = @"rate";
NSString *const ABI21_0_0EXAVPlayerDataStatusShouldCorrectPitchKeyPath = @"shouldCorrectPitch";
NSString *const ABI21_0_0EXAVPlayerDataStatusVolumeKeyPath = @"volume";
NSString *const ABI21_0_0EXAVPlayerDataStatusIsMutedKeyPath = @"isMuted";
NSString *const ABI21_0_0EXAVPlayerDataStatusIsLoopingKeyPath = @"isLooping";
NSString *const ABI21_0_0EXAVPlayerDataStatusDidJustFinishKeyPath = @"didJustFinish";

NSString *const ABI21_0_0EXAVPlayerDataObserverStatusKeyPath = @"status";
NSString *const ABI21_0_0EXAVPlayerDataObserverRateKeyPath = @"rate";
NSString *const ABI21_0_0EXAVPlayerDataObserverTimeControlStatusPath = @"timeControlStatus";
NSString *const ABI21_0_0EXAVPlayerDataObserverPlaybackBufferEmptyKeyPath = @"playbackBufferEmpty";

@interface ABI21_0_0EXAVPlayerData ()

@property (nonatomic, weak) ABI21_0_0EXAV *exAV;

@property (nonatomic, assign) BOOL isLoaded;
@property (nonatomic, strong) void (^loadFinishBlock)(BOOL success, NSDictionary *successStatus, NSString *error);

@property (nonatomic, strong) id <NSObject> timeObserver;
@property (nonatomic, strong) id <NSObject> finishObserver;
@property (nonatomic, strong) id <NSObject> playbackStalledObserver;

@property (nonatomic, strong) NSNumber *progressUpdateIntervalMillis;
@property (nonatomic, assign) CMTime currentPosition;
@property (nonatomic, assign) BOOL shouldPlay;
@property (nonatomic, strong) NSNumber *rate;
@property (nonatomic, assign) BOOL shouldCorrectPitch;
@property (nonatomic, strong) NSNumber* volume;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isLooping;

@end

@implementation ABI21_0_0EXAVPlayerData

#pragma mark - Static methods

+ (NSDictionary *)getUnloadedStatus
{
  return @{ABI21_0_0EXAVPlayerDataStatusIsLoadedKeyPath: @(NO)};
}

#pragma mark - Init and player loading

- (instancetype)initWithEXAV:(ABI21_0_0EXAV *)exAV
                     withURL:(NSURL *)url
                  withStatus:(NSDictionary *)parameters
         withLoadFinishBlock:(void (^)(BOOL success, NSDictionary *successStatus, NSString *error))loadFinishBlock
{
  if ((self = [super init])) {
    _exAV = exAV;
  
    _isLoaded = NO;
    _loadFinishBlock = loadFinishBlock;
  
    _player = nil;
  
    _url = url;
  
    _timeObserver = nil;
    _finishObserver = nil;
    _playbackStalledObserver = nil;
    _statusUpdateCallback = nil;
  
    // These status props will be potentially reset by the following call to [self setStatus:parameters ...].
    _progressUpdateIntervalMillis = @(500);
    _currentPosition = kCMTimeZero;
    _shouldPlay = NO;
    _rate = @(1.0);
    _shouldCorrectPitch = NO;
    _volume = @(1.0);
    _isMuted = NO;
    _isLooping = NO;
  
    [self setStatus:parameters resolver:nil rejecter:nil];
  
    [self _loadNewPlayer];
  }
  
  return self;
}

- (void)_loadNewPlayer
{
  NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
  AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:_url options:@{AVURLAssetHTTPCookiesKey : cookies}];
  
  // unless we preload, the asset will not necessarily load the duration by the time we try to play it.
  // http://stackoverflow.com/questions/20581567/avplayer-and-avfoundationerrordomain-code-11819
  __weak __typeof__(self) weakSelf = self;
  [avAsset loadValuesAsynchronouslyForKeys:@[ @"duration" ] completionHandler:^{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:avAsset];
    weakSelf.player = [AVPlayer playerWithPlayerItem:playerItem];
    if (weakSelf.player) {
      [weakSelf.player addObserver:weakSelf forKeyPath:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath options:0 context:nil];
      [playerItem addObserver:weakSelf forKeyPath:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath options:0 context:nil];
    } else {
      NSString *errorMessage = @"Load encountered an error: [AVPlayer playerWithPlayerItem:] returned nil.";
      if (weakSelf.loadFinishBlock) {
        weakSelf.loadFinishBlock(NO, nil, errorMessage);
        weakSelf.loadFinishBlock = nil;
      } else if (weakSelf.errorCallback) {
        weakSelf.errorCallback(errorMessage);
      }
    }
  }];
}

- (void)_finishLoadingNewPlayer
{
  // Set up player with parameters
  __weak __typeof__(self) weakSelf = self;
  [_player seekToTime:_currentPosition completionHandler:^(BOOL finished) {
    dispatch_async(weakSelf.exAV.methodQueue, ^{
      weakSelf.currentPosition = weakSelf.player.currentTime;
      
      if (weakSelf.shouldCorrectPitch) {
        weakSelf.player.currentItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmLowQualityZeroLatency;
      } else {
        weakSelf.player.currentItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmVarispeed;
      }
      weakSelf.player.volume = weakSelf.volume.floatValue;
      weakSelf.player.muted = weakSelf.isMuted;
      weakSelf.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
      
      [weakSelf _tryPlayPlayerWithRateAndMuteIfNecessary];
      
      weakSelf.isLoaded = YES;
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _addObserversForNewPlayer];
        
        if (weakSelf.loadFinishBlock) {
          weakSelf.loadFinishBlock(YES, [weakSelf getStatus], nil);
          weakSelf.loadFinishBlock = nil;
        }
      });
    });
  }];
}

#pragma mark - setStatus

- (BOOL)_shouldPlayerPlay
{
  return _shouldPlay && ![_rate isEqualToNumber:@(0)];
}

- (NSError *)_tryPlayPlayerWithRateAndMuteIfNecessary
{
  if (_player && [self _shouldPlayerPlay]) {
    NSError *error = [_exAV promoteAudioSessionIfNecessary];
    if (!error) {
      _player.muted = _isMuted;
      _player.rate = [_rate floatValue];
    }
    return error;
  }
  return nil;
}

- (void)setStatus:(NSDictionary *)parameters
         resolver:(ABI21_0_0RCTPromiseResolveBlock)resolve
         rejecter:(ABI21_0_0RCTPromiseRejectBlock)reject
{
  BOOL mustUpdateTimeObserver = NO;
  BOOL mustSeek = NO;
  
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusProgressUpdateIntervalMillisKeyPath] != nil) {
    NSNumber *progressUpdateIntervalMillis = parameters[ABI21_0_0EXAVPlayerDataStatusProgressUpdateIntervalMillisKeyPath];
    mustUpdateTimeObserver = ![progressUpdateIntervalMillis isEqualToNumber:_progressUpdateIntervalMillis];
    _progressUpdateIntervalMillis = progressUpdateIntervalMillis;
  }
  
  // To prevent a race condition, we set _currentPosition at the end of this method.
  CMTime newPosition = _currentPosition;
  
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusPositionMillisKeyPath] != nil) {
    NSNumber *currentPositionMillis = parameters[ABI21_0_0EXAVPlayerDataStatusPositionMillisKeyPath];
    
    // We only seek if the new position is different from _currentPosition by a whole number of milliseconds.
    mustSeek = currentPositionMillis.longValue != [self _getRoundedMillisFromCMTime:_currentPosition].longValue;
    if (mustSeek) {
      newPosition = CMTimeMakeWithSeconds(currentPositionMillis.floatValue / 1000, NSEC_PER_SEC);
    }
  }
  
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusShouldPlayKeyPath] != nil) {
    NSNumber *shouldPlay = parameters[ABI21_0_0EXAVPlayerDataStatusShouldPlayKeyPath];
    _shouldPlay = shouldPlay.boolValue;
  }
  
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusRateKeyPath] != nil) {
    NSNumber *rate = parameters[ABI21_0_0EXAVPlayerDataStatusRateKeyPath];
    _rate = rate;
  }
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusShouldCorrectPitchKeyPath] != nil) {
    NSNumber *shouldCorrectPitch = parameters[ABI21_0_0EXAVPlayerDataStatusShouldCorrectPitchKeyPath];
    _shouldCorrectPitch = shouldCorrectPitch.boolValue;
  }
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusVolumeKeyPath] != nil) {
    NSNumber *volume = parameters[ABI21_0_0EXAVPlayerDataStatusVolumeKeyPath];
    _volume = volume;
  }
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusIsMutedKeyPath] != nil) {
    NSNumber *isMuted = parameters[ABI21_0_0EXAVPlayerDataStatusIsMutedKeyPath];
    _isMuted = isMuted.boolValue;
  }
  if ([parameters objectForKey:ABI21_0_0EXAVPlayerDataStatusIsLoopingKeyPath] != nil) {
    NSNumber *isLooping = parameters[ABI21_0_0EXAVPlayerDataStatusIsLoopingKeyPath];
    _isLooping = isLooping.boolValue;
  }
  
  if (_player && _isLoaded) {
    // Pause / mute first if necessary.
    if (![self _shouldPlayerPlay]) {
      [_player pause];
    }
    if (_isMuted || ![self _isPlayerPlaying]) {
      _player.muted = _isMuted;
    }
    [_exAV demoteAudioSessionIfPossible];
    
    // Apply idempotent parameters.
    if (_shouldCorrectPitch) {
      _player.currentItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmLowQualityZeroLatency;
    } else {
      _player.currentItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmVarispeed;
    }
    _player.volume = _volume.floatValue;
    
    
    // Apply parameters necessary after seek.
    __weak __typeof__(self) weakSelf = self;
    void (^applyPostSeekParameters)(BOOL) = ^(BOOL seekSucceeded) {
      weakSelf.currentPosition = weakSelf.player.currentTime;
      
      if (mustUpdateTimeObserver) {
        [weakSelf _updateTimeObserver];
      }
      
      NSError *audioSessionError = [weakSelf _tryPlayPlayerWithRateAndMuteIfNecessary];
      
      if (audioSessionError) {
        if (reject) {
          reject(@"E_AV_PLAY", @"Play encountered an error: audio session not activated.", audioSessionError);
        }
      } else if (!seekSucceeded) {
        if (reject) {
          reject(@"E_AV_SEEKING", nil, ABI21_0_0RCTErrorWithMessage(@"Seeking interrupted."));
        }
      } else if (resolve) {
        resolve([weakSelf getStatus]);
      }
      
      if (!resolve || !reject) {
        [self _callStatusUpdateCallback];
      }
    };
    
    // Apply seek if necessary.
    if (mustSeek) {
      [_player seekToTime:newPosition completionHandler:^(BOOL seekSucceeded) {
        dispatch_async(_exAV.methodQueue, ^{
          applyPostSeekParameters(seekSucceeded);
        });
      }];
    } else {
      applyPostSeekParameters(YES);
    }
  } else {
    _currentPosition = newPosition; // Will be set in the new _player on the call to [self _finishLoadingNewPlayer].
    if (resolve) {
      resolve([ABI21_0_0EXAVPlayerData getUnloadedStatus]);
    }
  }
}

#pragma mark - getStatus

- (BOOL)_isPlayerPlaying
{
  if ([_player respondsToSelector:@selector(timeControlStatus)]) {
    // Only available after iOS 10
    return [_player timeControlStatus] == AVPlayerTimeControlStatusPlaying;
  } else {
    // timeControlStatus is preferable to this when available
    // See http://stackoverflow.com/questions/5655864/check-play-state-of-avplayer
    return _player.rate != 0 && _player.error == nil;
  }
}

- (NSNumber *)_getRoundedMillisFromCMTime:(CMTime)time
{
  return CMTIME_IS_INVALID(time) || CMTIME_IS_INDEFINITE(time) ? nil : @((long) (CMTimeGetSeconds(time) * 1000));
}

- (NSNumber *)_getClippedValueForValue:(NSNumber *)value withMin:(NSNumber *)min withMax:(NSNumber *)max
{
  return (min != nil && [value doubleValue] < [min doubleValue]) ? min
       : (max != nil && [value doubleValue] > [max doubleValue]) ? max
       : value;
}

- (NSDictionary *)getStatus
{
  if (!_isLoaded || _player == nil) {
    return [ABI21_0_0EXAVPlayerData getUnloadedStatus];
  }
  
  AVPlayerItem *currentItem = _player.currentItem;
  if (_player.status != AVPlayerStatusReadyToPlay || currentItem.status != AVPlayerItemStatusReadyToPlay) {
    return [ABI21_0_0EXAVPlayerData getUnloadedStatus];
  }
  
  // Get duration and position:
  NSNumber *durationMillis = [self _getRoundedMillisFromCMTime:currentItem.duration];
  if (durationMillis) {
    durationMillis = [durationMillis doubleValue] < 0 ? 0 : durationMillis;
  }
  
  NSNumber *positionMillis = [self _getRoundedMillisFromCMTime:[_player currentTime]];
  positionMillis = [self _getClippedValueForValue:positionMillis withMin:@(0) withMax:durationMillis];
  
  // Calculate playable duration:
  NSNumber *playableDurationMillis;
  if (_player.status == AVPlayerStatusReadyToPlay) {
    __block CMTimeRange effectiveTimeRange;
    [currentItem.loadedTimeRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      CMTimeRange timeRange = [obj CMTimeRangeValue];
      if (CMTimeRangeContainsTime(timeRange, currentItem.currentTime)) {
        effectiveTimeRange = timeRange;
        *stop = YES;
      }
    }];
    playableDurationMillis = [self _getRoundedMillisFromCMTime:CMTimeRangeGetEnd(effectiveTimeRange)];
    if (playableDurationMillis) {
      playableDurationMillis = [self _getClippedValueForValue:playableDurationMillis withMin:@(0) withMax:durationMillis];
    }
  }
  
  // Calculate if the player is buffering
  BOOL isPlaying = [self _isPlayerPlaying];
  BOOL isBuffering;
  if (isPlaying) {
    isBuffering = NO;
  } else if ([_player respondsToSelector:@selector(timeControlStatus)]) {
    // Only available after iOS 10
    isBuffering = _player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate;
  } else {
    isBuffering = _player.currentItem.isPlaybackBufferEmpty;
  }
  
  // TODO : ReactABI21_0_0-native-video includes the iOS-only keys seekableDuration and canReverse (etc) flags.
  //        Consider adding these.
  NSMutableDictionary *mutableStatus = [@{ABI21_0_0EXAVPlayerDataStatusIsLoadedKeyPath: @(YES),
                                          
                                          ABI21_0_0EXAVPlayerDataStatusURIKeyPath: [_url absoluteString],
                                          
                                          ABI21_0_0EXAVPlayerDataStatusProgressUpdateIntervalMillisKeyPath: _progressUpdateIntervalMillis,
                                          ABI21_0_0EXAVPlayerDataStatusPositionMillisKeyPath: positionMillis,
                                          // playableDurationMillis, and durationMillis may be nil and are added after this definition.
                                          
                                          ABI21_0_0EXAVPlayerDataStatusShouldPlayKeyPath: @(_shouldPlay),
                                          ABI21_0_0EXAVPlayerDataStatusIsPlayingKeyPath: @(isPlaying),
                                          ABI21_0_0EXAVPlayerDataStatusIsBufferingKeyPath: @(isBuffering),
                                          
                                          ABI21_0_0EXAVPlayerDataStatusRateKeyPath: _rate,
                                          ABI21_0_0EXAVPlayerDataStatusShouldCorrectPitchKeyPath: @(_shouldCorrectPitch),
                                          ABI21_0_0EXAVPlayerDataStatusVolumeKeyPath: @(_player.volume),
                                          ABI21_0_0EXAVPlayerDataStatusIsMutedKeyPath: @(_player.muted),
                                          ABI21_0_0EXAVPlayerDataStatusIsLoopingKeyPath: @(_isLooping),
                                          
                                          ABI21_0_0EXAVPlayerDataStatusDidJustFinishKeyPath: @(NO),
                                          } mutableCopy];
  
  mutableStatus[ABI21_0_0EXAVPlayerDataStatusPlayableDurationMillisKeyPath] = playableDurationMillis;
  mutableStatus[ABI21_0_0EXAVPlayerDataStatusDurationMillisKeyPath] = durationMillis;
  
  return mutableStatus;
}

- (void)_callStatusUpdateCallbackWithExtraFields:(NSDictionary *)extraFields
{
  NSDictionary *status;
  if (extraFields) {
    NSMutableDictionary *mutableStatus = [[self getStatus] mutableCopy];
    [mutableStatus addEntriesFromDictionary:extraFields];
    status = mutableStatus;
  } else {
    status = [self getStatus];
  }
  if (_statusUpdateCallback) {
    _statusUpdateCallback(status);
  }
}

- (void)_callStatusUpdateCallback
{
  [self _callStatusUpdateCallbackWithExtraFields:nil];
}

#pragma mark - Observers

- (void)_tryRemoveObserver:(NSObject *)object forKeyPath:(NSString *)path
{
  @try {
    [object removeObserver:self forKeyPath:path];
  } @catch (NSException *exception) {
    // no-op
  }
}

- (void)_removeObservers
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  
  [self _tryRemoveObserver:_player forKeyPath:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath];
  [self _tryRemoveObserver:_player.currentItem forKeyPath:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath];
  
  if (_finishObserver) {
    [center removeObserver:_finishObserver];
    _finishObserver = nil;
  }
  if (_playbackStalledObserver) {
    [center removeObserver:_playbackStalledObserver];
    _playbackStalledObserver = nil;
  }
  
  [self _tryRemoveObserver:_player forKeyPath:ABI21_0_0EXAVPlayerDataObserverRateKeyPath];
  [self _tryRemoveObserver:_player forKeyPath:ABI21_0_0EXAVPlayerDataObserverTimeControlStatusPath];
  [self _tryRemoveObserver:_player.currentItem forKeyPath:ABI21_0_0EXAVPlayerDataObserverPlaybackBufferEmptyKeyPath];
}

- (void)_removeTimeObserver
{
  if (_timeObserver) {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

- (void)_updateTimeObserver
{
  [self _removeTimeObserver];
  
  __weak __typeof__(self) weakSelf = self;
  
  CMTime interval = CMTimeMakeWithSeconds(_progressUpdateIntervalMillis.floatValue / 1000.0, NSEC_PER_SEC);
  
  void (^timeObserverBlock)(CMTime time) = ^(CMTime time) {
    __strong __typeof__(self) strongSelfOuter = weakSelf;
    __strong ABI21_0_0EXAV *strongEXAV = strongSelfOuter ? strongSelfOuter.exAV : nil;
    
    if (strongEXAV) {
      dispatch_async(strongEXAV.methodQueue, ^{
        __strong __typeof__(self) strongSelfInner = weakSelf;
        
        if (strongSelfInner && strongSelfInner.player.status == AVPlayerStatusReadyToPlay) {
          strongSelfInner.currentPosition = time; // We keep track of _currentPosition to reset the AVPlayer in handleMediaServicesReset.
          [strongSelfInner _callStatusUpdateCallback];
        }
      });
    }
  };
  
  _timeObserver = [_player addPeriodicTimeObserverForInterval:interval
                                                        queue:NULL
                                                   usingBlock:timeObserverBlock];
}

- (void)_addObserversForNewPlayer
{
  [self _removeObservers];
  [self _updateTimeObserver];
  
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  
  __weak __typeof__(self) weakSelf = self;
  
  void (^didPlayToEndTimeObserverBlock)(NSNotification *note) = ^(NSNotification *note) {
    __strong __typeof__(self) strongSelf = weakSelf;
    
    if (strongSelf) {
      [strongSelf _callStatusUpdateCallbackWithExtraFields:@{ABI21_0_0EXAVPlayerDataStatusDidJustFinishKeyPath: @(YES)}];
      if (strongSelf.isLooping) {
        [strongSelf.player seekToTime:kCMTimeZero];
        strongSelf.player.rate = strongSelf.rate.floatValue;
      } else {
        [strongSelf.exAV demoteAudioSessionIfPossible];
      }
    }
  };
  
  _finishObserver = [center addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                        object:[_player currentItem]
                                         queue:nil
                                    usingBlock:didPlayToEndTimeObserverBlock];
  
  void (^playbackStalledObserverBlock)(NSNotification *note) = ^(NSNotification *note) {
    [weakSelf _callStatusUpdateCallback];
  };
  
  _playbackStalledObserver = [center addObserverForName:AVPlayerItemPlaybackStalledNotification
                                                 object:[_player currentItem]
                                                  queue:nil
                                             usingBlock:playbackStalledObserverBlock];

  [_player addObserver:self forKeyPath:ABI21_0_0EXAVPlayerDataObserverRateKeyPath options:0 context:nil];
  [_player addObserver:self forKeyPath:ABI21_0_0EXAVPlayerDataObserverTimeControlStatusPath options:0 context:nil]; // Only available after iOS 10
  [_player.currentItem addObserver:self forKeyPath:ABI21_0_0EXAVPlayerDataObserverPlaybackBufferEmptyKeyPath options:0 context:nil];
}



- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (_player == nil || (object != _player && object != _player.currentItem)) {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    return;
  }
  
  __strong ABI21_0_0EXAV *strongEXAV = _exAV;
  if (strongEXAV == nil) {
    return;
  }
  
  dispatch_async(strongEXAV.methodQueue, ^{
    if (object == _player) {
      if ([keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath]) {
        switch (_player.status) {
          case AVPlayerStatusUnknown:
            break;
          case AVPlayerStatusReadyToPlay:
            if (!_isLoaded && _player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
              [self _finishLoadingNewPlayer];
            }
            break;
          case AVPlayerStatusFailed: {
            _isLoaded = NO;
            NSString *errorMessage = [NSString stringWithFormat:@"The AVPlayer instance has failed with the error code %li and domain \"%@\".", _player.error.code, _player.error.domain];
            if (_loadFinishBlock) {
              _loadFinishBlock(NO, nil, errorMessage);
              _loadFinishBlock = nil;
            } else if (_errorCallback) {
              _errorCallback(errorMessage);
            }
            break;
          }
        }
      } else if ([keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverRateKeyPath]) {
        if (_player.rate != 0) {
          _rate = @(_player.rate);
        }
        [self _callStatusUpdateCallback];
      } else if ([keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverTimeControlStatusPath]
                 || [keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath]) {
        [self _callStatusUpdateCallback];
      }
    } else if (object == _player.currentItem) {
      if ([keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath]) {
        switch (_player.currentItem.status) {
          case AVPlayerItemStatusUnknown:
            break;
          case AVPlayerItemStatusReadyToPlay:
            if (!_isLoaded && _player.status == AVPlayerItemStatusReadyToPlay) {
              [self _finishLoadingNewPlayer];
            }
            break;
          case AVPlayerItemStatusFailed: {
            NSString *errorMessage = [NSString stringWithFormat:@"The AVPlayerItem instance has failed with the error code %li and domain \"%@\".", _player.currentItem.error.code, _player.currentItem.error.domain];
            if (_loadFinishBlock) {
              _loadFinishBlock(NO, nil, errorMessage);
              _loadFinishBlock = nil;
            } else if (_errorCallback) {
              _errorCallback(errorMessage);
            }
            _isLoaded = NO;
            break;
          }
        }
      } else if ([keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverPlaybackBufferEmptyKeyPath]
                 || [keyPath isEqualToString:ABI21_0_0EXAVPlayerDataObserverStatusKeyPath]) {
        [self _callStatusUpdateCallback];
      }
    }
  });
}

#pragma mark - ABI21_0_0EXAVObject

- (void)pauseImmediately
{
  if (_player) {
    [_player pause];
  }
}

- (ABI21_0_0EXAVAudioSessionMode)getAudioSessionModeRequired
{
  if (_player && ([self _isPlayerPlaying] || [self _shouldPlayerPlay])) {
    return _isMuted ? ABI21_0_0EXAVAudioSessionModeActiveMuted : ABI21_0_0EXAVAudioSessionModeActive;
  }
  return ABI21_0_0EXAVAudioSessionModeInactive;
}

- (void)bridgeDidForeground:(NSNotification *)notification
{
  [self _tryPlayPlayerWithRateAndMuteIfNecessary];
}

- (void)bridgeDidBackground:(NSNotification *)notification
{
  // ABI21_0_0EXAudio already forced pause.
}

- (void)handleAudioSessionInterruption:(NSNotification*)notification
{
  NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
  switch (interruptionType.unsignedIntegerValue) {
    case AVAudioSessionInterruptionTypeBegan:
      // System already forced pause.
      [self _callStatusUpdateCallback];
      break;
    case AVAudioSessionInterruptionTypeEnded:
      [self _tryPlayPlayerWithRateAndMuteIfNecessary];
      [self _callStatusUpdateCallback];
      break;
    default:
      break;
  }
}

- (void)handleMediaServicesReset:(void (^)())finishCallback
{
  // See here: https://developer.apple.com/library/content/qa/qa1749/_index.html
  // (this is an unlikely notification to receive, but best practices suggests that we catch it just in case)
  
  _isLoaded = NO;
  
  // We want to temporarily disable _statusUpdateCallback so that all of the new state changes don't trigger a waterfall of updates:
  void (^callback)(NSDictionary *) = _statusUpdateCallback;
  _statusUpdateCallback = nil;
  __weak __typeof__(self) weakSelf = self;
  
  _loadFinishBlock = ^(BOOL success, NSDictionary *successStatus, NSString *error) {
    if (finishCallback != nil) {
      finishCallback();
    }
    if (weakSelf.statusUpdateCallback == nil) {
      weakSelf.statusUpdateCallback = callback;
    }
    [weakSelf _callStatusUpdateCallback];
    if (!success && weakSelf.errorCallback) {
      weakSelf.errorCallback(error);
    }
  };
  
  [self _removeTimeObserver];
  [self _removeObservers];
  
  [self _loadNewPlayer];
}

#pragma mark - NSObject Lifecycle

- (void)dealloc
{
  [self _removeTimeObserver];
  [self _removeObservers];
}

@end
