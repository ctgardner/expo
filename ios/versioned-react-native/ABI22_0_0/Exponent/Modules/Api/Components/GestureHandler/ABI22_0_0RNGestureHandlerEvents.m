#import "ABI22_0_0RNGestureHandlerEvents.h"

#define SAFE_VELOCITY(velocity) @(isnan(velocity) ? 0 : velocity)

@implementation ABI22_0_0RNGestureHandlerEventExtraData

- (instancetype)initWithData:(NSDictionary *)data;
{
    if ((self = [super init])) {
        _data = data;
    }
    return self;
}

+ (ABI22_0_0RNGestureHandlerEventExtraData *)forPosition:(CGPoint)position
                           withAbsolutePosition:(CGPoint)absolutePosition
{
    return [[ABI22_0_0RNGestureHandlerEventExtraData alloc]
            initWithData:@{
                           @"x": @(position.x),
                           @"y": @(position.y),
                           @"absoluteX": @(absolutePosition.x),
                           @"absoluteY": @(absolutePosition.y)}];
}

+ (ABI22_0_0RNGestureHandlerEventExtraData *)forPan:(CGPoint)position
                      withAbsolutePosition:(CGPoint)absolutePosition
                           withTranslation:(CGPoint)translation
                              withVelocity:(CGPoint)velocity
{
    return [[ABI22_0_0RNGestureHandlerEventExtraData alloc]
            initWithData:@{
                           @"x": @(position.x),
                           @"y": @(position.y),
                           @"absoluteX": @(absolutePosition.x),
                           @"absoluteY": @(absolutePosition.y),
                           @"translationX": @(translation.x),
                           @"translationY": @(translation.y),
                           @"velocityX": SAFE_VELOCITY(velocity.x),
                           @"velocityY": SAFE_VELOCITY(velocity.y)}];
}

+ (ABI22_0_0RNGestureHandlerEventExtraData *)forPinch:(CGFloat)scale
                              withFocalPoint:(CGPoint)focalPoint
                                withVelocity:(CGFloat)velocity
{
    return [[ABI22_0_0RNGestureHandlerEventExtraData alloc]
            initWithData:@{
                           @"scale": @(scale),
                           @"focalX": @(focalPoint.x),
                           @"focalY": @(focalPoint.y),
                           @"velocity": SAFE_VELOCITY(velocity)}];
}

+ (ABI22_0_0RNGestureHandlerEventExtraData *)forRotation:(CGFloat)rotation
                                withAnchorPoint:(CGPoint)anchorPoint
                                   withVelocity:(CGFloat)velocity
{
    return [[ABI22_0_0RNGestureHandlerEventExtraData alloc]
            initWithData:@{@"rotation": @(rotation),
                           @"anchorX": @(anchorPoint.x),
                           @"anchorY": @(anchorPoint.y),
                           @"velocity": SAFE_VELOCITY(velocity)}];
}

+ (ABI22_0_0RNGestureHandlerEventExtraData *)forPointerInside:(BOOL)pointerInside;
{
    return [[ABI22_0_0RNGestureHandlerEventExtraData alloc] initWithData:@{@"pointerInside": @(pointerInside)}];
}

@end


@implementation ABI22_0_0RNGestureHandlerEvent
{
    NSNumber *_handlerTag;
    ABI22_0_0RNGestureHandlerState _state;
    ABI22_0_0RNGestureHandlerEventExtraData *_extraData;
}

@synthesize viewTag = _viewTag;
@synthesize coalescingKey = _coalescingKey;

- (instancetype)initWithRactTag:(NSNumber *)ReactABI22_0_0Tag
                     handlerTag:(NSNumber *)handlerTag
                          state:(ABI22_0_0RNGestureHandlerState)state
                      extraData:(ABI22_0_0RNGestureHandlerEventExtraData *)extraData
{
    static uint16_t coalescingKey = 0;
    if ((self = [super init])) {
        _viewTag = ReactABI22_0_0Tag;
        _handlerTag = handlerTag;
        _state = state;
        _extraData = extraData;
        _coalescingKey = coalescingKey++;
    }
    return self;
}

ABI22_0_0RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (NSString *)eventName
{
    return @"onGestureHandlerEvent";
}

- (BOOL)canCoalesce
{
    // TODO: event coalescing
    return NO;
}

- (id<ABI22_0_0RCTEvent>)coalesceWithEvent:(id<ABI22_0_0RCTEvent>)newEvent;
{
    return newEvent;
}

+ (NSString *)moduleDotMethod
{
    return @"ABI22_0_0RCTEventEmitter.receiveEvent";
}

- (NSArray *)arguments
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:_extraData.data];
    [body setObject:_viewTag forKey:@"target"];
    [body setObject:_handlerTag forKey:@"handlerTag"];
    [body setObject:@(_state) forKey:@"state"];
    return @[self.viewTag, @"topGestureHandlerEvent", body];
}

@end


@implementation ABI22_0_0RNGestureHandlerStateChange
{
    NSNumber *_handlerTag;
    ABI22_0_0RNGestureHandlerState _state;
    ABI22_0_0RNGestureHandlerState _prevState;
    ABI22_0_0RNGestureHandlerEventExtraData *_extraData;
}

@synthesize viewTag = _viewTag;
@synthesize coalescingKey = _coalescingKey;

- (instancetype)initWithRactTag:(NSNumber *)ReactABI22_0_0Tag
                     handlerTag:(NSNumber *)handlerTag
                          state:(ABI22_0_0RNGestureHandlerState)state
                      prevState:(ABI22_0_0RNGestureHandlerState)prevState
                      extraData:(ABI22_0_0RNGestureHandlerEventExtraData *)extraData
{
    static uint16_t coalescingKey = 0;
    if ((self = [super init])) {
        _viewTag = ReactABI22_0_0Tag;
        _handlerTag = handlerTag;
        _state = state;
        _prevState = prevState;
        _extraData = extraData;
        _coalescingKey = coalescingKey++;
    }
    return self;
}

ABI22_0_0RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (NSString *)eventName
{
    return @"onGestureHandlerStateChange";
}

- (BOOL)canCoalesce
{
    // TODO: event coalescing
    return NO;
}

- (id<ABI22_0_0RCTEvent>)coalesceWithEvent:(id<ABI22_0_0RCTEvent>)newEvent;
{
    return newEvent;
}

+ (NSString *)moduleDotMethod
{
    return @"ABI22_0_0RCTEventEmitter.receiveEvent";
}

- (NSArray *)arguments
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:_extraData.data];
    [body setObject:_viewTag forKey:@"target"];
    [body setObject:_handlerTag forKey:@"handlerTag"];
    [body setObject:@(_state) forKey:@"state"];
    [body setObject:@(_prevState) forKey:@"oldState"];
    return @[self.viewTag, @"topGestureHandlerStateChange", body];
}

@end
