// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI23_0_0EXPedometer.h"
#import "ABI23_0_0EXUnversioned.h"

#import <CoreMotion/CoreMotion.h>

NSString * const ABI23_0_0EXPedometerUpdateEventName = @"Exponent.pedometerUpdate";

@implementation ABI23_0_0EXPedometer
{
  CMPedometer *_pedometer;
  BOOL _isWatching;
  CMPedometerHandler _watchHandler;
  NSDate *_watchStartDate;
}

- (void)setBridge:(ABI23_0_0RCTBridge *)bridge
{
  [super setBridge:bridge];
  _isWatching = NO;

  __weak typeof(self) weakSelf = self;
  _watchHandler = ^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
    if (error) {
      // TODO: Handle errors
      return;
    }
    [weakSelf sendEventWithName:ABI23_0_0EXPedometerUpdateEventName
                           body:@{@"steps": pedometerData.numberOfSteps}];
  };

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(bridgeDidForeground:)
                                               name:@"EXKernelBridgeDidForegroundNotification"
                                             object:self.bridge];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(bridgeDidBackground:)
                                               name:@"EXKernelBridgeDidBackgroundNotification"
                                             object:self.bridge];
}

- (void)bridgeDidForeground:(NSNotification *)notification
{
  if (_isWatching) {
    [_pedometer startPedometerUpdatesFromDate:_watchStartDate withHandler:_watchHandler];
  }
}

- (void)bridgeDidBackground:(NSNotification *)notification
{
  if (_isWatching) {
    [_pedometer stopPedometerUpdates];
  }
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self stopWatchingStepCount];
}

ABI23_0_0RCT_EXPORT_MODULE(ExponentPedometer)

- (NSArray<NSString *> *)supportedEvents
{
  return @[ABI23_0_0EXPedometerUpdateEventName];
}

ABI23_0_0RCT_EXPORT_METHOD(getStepCountAsync:(nonnull NSNumber *)startTime
                            endTime:(nonnull NSNumber *)endTime
                           resolver:(ABI23_0_0RCTPromiseResolveBlock)resolve
                           rejecter:(ABI23_0_0RCTPromiseRejectBlock)reject)
{
  if (!_pedometer) {
    _pedometer = [CMPedometer new];
  }

  NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:startTime.doubleValue / 1000];
  NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:endTime.doubleValue / 1000];
  [_pedometer queryPedometerDataFromDate:startDate toDate:endDate withHandler:^(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error) {
    if (error) {
      reject(@"E_PEDOMETER", @"An error occured while querying pedometer data.", error);
      return;
    }

    resolve(@{@"steps": pedometerData.numberOfSteps});
  }];
}

ABI23_0_0RCT_EXPORT_METHOD(watchStepCount)
{
  if (!_pedometer) {
    _pedometer = [CMPedometer new];
  }
  [_pedometer stopPedometerUpdates];

  _isWatching = YES;
  _watchStartDate = [NSDate date];
  [_pedometer startPedometerUpdatesFromDate:_watchStartDate withHandler:_watchHandler];
}

ABI23_0_0RCT_EXPORT_METHOD(stopWatchingStepCount)
{
  _watchStartDate = nil;
  _isWatching = NO;
  [_pedometer stopPedometerUpdates];
}

ABI23_0_0RCT_EXPORT_METHOD(isAvailableAsync:(ABI23_0_0RCTPromiseResolveBlock)resolve rejecter:(ABI23_0_0RCTPromiseRejectBlock)reject)
{
  resolve(@([CMPedometer isStepCountingAvailable]));
}

@end
