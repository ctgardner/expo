/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI10_0_0RCTFont.h"
#import "ABI10_0_0RCTLog.h"

#import <CoreText/CoreText.h>

#import <mutex>

#if !defined(__IPHONE_8_2) || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_2

// These constants are defined in iPhone SDK 8.2, but the app cannot run on
// iOS < 8.2 unless we redefine them here. If you target iOS 8.2 or above
// as a base target, the standard constants will be used instead.
// These constants can only be removed when ReactABI10_0_0 Native drops iOS8 support.

#define UIFontWeightUltraLight -0.8
#define UIFontWeightThin -0.6
#define UIFontWeightLight -0.4
#define UIFontWeightRegular 0
#define UIFontWeightMedium 0.23
#define UIFontWeightSemibold 0.3
#define UIFontWeightBold 0.4
#define UIFontWeightHeavy 0.56
#define UIFontWeightBlack 0.62

#endif

typedef CGFloat ABI10_0_0RCTFontWeight;
static ABI10_0_0RCTFontWeight weightOfFont(UIFont *font)
{
  static NSDictionary *nameToWeight;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    nameToWeight = @{
       @"normal": @(UIFontWeightRegular),
       @"bold": @(UIFontWeightBold),
       @"ultralight": @(UIFontWeightUltraLight),
       @"thin": @(UIFontWeightThin),
       @"light": @(UIFontWeightLight),
       @"regular": @(UIFontWeightRegular),
       @"medium": @(UIFontWeightMedium),
       @"semibold": @(UIFontWeightSemibold),
       @"bold": @(UIFontWeightBold),
       @"heavy": @(UIFontWeightHeavy),
       @"black": @(UIFontWeightBlack),
    };
  });

  NSDictionary *traits = [font.fontDescriptor objectForKey:UIFontDescriptorTraitsAttribute];
  ABI10_0_0RCTFontWeight weight = [traits[UIFontWeightTrait] doubleValue];
  if (weight == 0.0) {
    for (NSString *name in nameToWeight) {
      if ([font.fontName.lowercaseString hasSuffix:name]) {
        return [nameToWeight[name] doubleValue];
      }
    }
  }
  return weight;
}

static BOOL isItalicFont(UIFont *font)
{
  NSDictionary *traits = [font.fontDescriptor objectForKey:UIFontDescriptorTraitsAttribute];
  UIFontDescriptorSymbolicTraits symbolicTraits = [traits[UIFontSymbolicTrait] unsignedIntValue];
  return (symbolicTraits & UIFontDescriptorTraitItalic) != 0;
}

static BOOL isCondensedFont(UIFont *font)
{
  NSDictionary *traits = [font.fontDescriptor objectForKey:UIFontDescriptorTraitsAttribute];
  UIFontDescriptorSymbolicTraits symbolicTraits = [traits[UIFontSymbolicTrait] unsignedIntValue];
  return (symbolicTraits & UIFontDescriptorTraitCondensed) != 0;
}

static UIFont *cachedSystemFont(CGFloat size, ABI10_0_0RCTFontWeight weight)
{
  static NSCache *fontCache;
  static std::mutex fontCacheMutex;

  NSString *cacheKey = [NSString stringWithFormat:@"%.1f/%.2f", size, weight];
  UIFont *font;
  {
    std::lock_guard<std::mutex> lock(fontCacheMutex);
    if (!fontCache) {
      fontCache = [NSCache new];
    }
    font = [fontCache objectForKey:cacheKey];
  }

  if (!font) {
    // Only supported on iOS8.2 and above
    if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)]) {
      font = [UIFont systemFontOfSize:size weight:weight];
    } else {
      if (weight >= UIFontWeightBold) {
        font = [UIFont boldSystemFontOfSize:size];
      } else if (weight >= UIFontWeightMedium) {
        font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
      } else if (weight <= UIFontWeightLight) {
        font = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
      } else {
        font = [UIFont systemFontOfSize:size];
      }
    }

    {
      std::lock_guard<std::mutex> lock(fontCacheMutex);
      [fontCache setObject:font forKey:cacheKey];
    }
  }

  return font;
}

@implementation ABI10_0_0RCTConvert (ABI10_0_0RCTFont)

+ (UIFont *)UIFont:(id)json
{
  json = [self NSDictionary:json];
  return [ABI10_0_0RCTFont updateFont:nil
                  withFamily:[ABI10_0_0RCTConvert NSString:json[@"fontFamily"]]
                        size:[ABI10_0_0RCTConvert NSNumber:json[@"fontSize"]]
                      weight:[ABI10_0_0RCTConvert NSString:json[@"fontWeight"]]
                       style:[ABI10_0_0RCTConvert NSString:json[@"fontStyle"]]
                     variant:[ABI10_0_0RCTConvert NSStringArray:json[@"fontVariant"]]
             scaleMultiplier:1];
}

ABI10_0_0RCT_ENUM_CONVERTER(ABI10_0_0RCTFontWeight, (@{
                                     @"normal": @(UIFontWeightRegular),
                                     @"bold": @(UIFontWeightBold),
                                     @"100": @(UIFontWeightUltraLight),
                                     @"200": @(UIFontWeightThin),
                                     @"300": @(UIFontWeightLight),
                                     @"400": @(UIFontWeightRegular),
                                     @"500": @(UIFontWeightMedium),
                                     @"600": @(UIFontWeightSemibold),
                                     @"700": @(UIFontWeightBold),
                                     @"800": @(UIFontWeightHeavy),
                                     @"900": @(UIFontWeightBlack),
                                     }), UIFontWeightRegular, doubleValue)

typedef BOOL ABI10_0_0RCTFontStyle;
ABI10_0_0RCT_ENUM_CONVERTER(ABI10_0_0RCTFontStyle, (@{
                                    @"normal": @NO,
                                    @"italic": @YES,
                                    @"oblique": @YES,
                                    }), NO, boolValue)

typedef NSDictionary ABI10_0_0RCTFontVariantDescriptor;
+ (ABI10_0_0RCTFontVariantDescriptor *)ABI10_0_0RCTFontVariantDescriptor:(id)json
{
  static NSDictionary *mapping;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    mapping = @{
      @"small-caps": @{
          UIFontFeatureTypeIdentifierKey: @(kLowerCaseType),
          UIFontFeatureSelectorIdentifierKey: @(kLowerCaseSmallCapsSelector),
          },
      @"oldstyle-nums": @{
          UIFontFeatureTypeIdentifierKey: @(kNumberCaseType),
          UIFontFeatureSelectorIdentifierKey: @(kLowerCaseNumbersSelector),
          },
      @"lining-nums": @{
          UIFontFeatureTypeIdentifierKey: @(kNumberCaseType),
          UIFontFeatureSelectorIdentifierKey: @(kUpperCaseNumbersSelector),
          },
      @"tabular-nums": @{
          UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
          UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector),
          },
      @"proportional-nums": @{
          UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
          UIFontFeatureSelectorIdentifierKey: @(kProportionalNumbersSelector),
          },
      };
  });
  ABI10_0_0RCTFontVariantDescriptor *value = mapping[json];
  if (ABI10_0_0RCT_DEBUG && !value && [json description].length > 0) {
    ABI10_0_0RCTLogError(@"Invalid ABI10_0_0RCTFontVariantDescriptor '%@'. should be one of: %@", json,
                [[mapping allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]);
  }
  return value;
}

ABI10_0_0RCT_ARRAY_CONVERTER(ABI10_0_0RCTFontVariantDescriptor)

@end

@implementation ABI10_0_0RCTFont

+ (UIFont *)updateFont:(UIFont *)font
            withFamily:(NSString *)family
                  size:(NSNumber *)size
                weight:(NSString *)weight
                 style:(NSString *)style
               variant:(NSArray<ABI10_0_0RCTFontVariantDescriptor *> *)variant
       scaleMultiplier:(CGFloat)scaleMultiplier
{
  // Defaults
  static NSString *defaultFontFamily;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultFontFamily = [UIFont systemFontOfSize:14].familyName;
  });
  const ABI10_0_0RCTFontWeight defaultFontWeight = UIFontWeightRegular;
  const CGFloat defaultFontSize = 14;

  // Initialize properties to defaults
  CGFloat fontSize = defaultFontSize;
  ABI10_0_0RCTFontWeight fontWeight = defaultFontWeight;
  NSString *familyName = defaultFontFamily;
  BOOL isItalic = NO;
  BOOL isCondensed = NO;

  if (font) {
    familyName = font.familyName ?: defaultFontFamily;
    fontSize = font.pointSize ?: defaultFontSize;
    fontWeight = weightOfFont(font);
    isItalic = isItalicFont(font);
    isCondensed = isCondensedFont(font);
  }

  // Get font attributes
  fontSize = [ABI10_0_0RCTConvert CGFloat:size] ?: fontSize;
  if (scaleMultiplier > 0.0 && scaleMultiplier != 1.0) {
    fontSize = round(fontSize * scaleMultiplier);
  }
  familyName = [ABI10_0_0RCTConvert NSString:family] ?: familyName;
  isItalic = style ? [ABI10_0_0RCTConvert ABI10_0_0RCTFontStyle:style] : isItalic;
  fontWeight = weight ? [ABI10_0_0RCTConvert ABI10_0_0RCTFontWeight:weight] : fontWeight;

  BOOL didFindFont = NO;

  // Handle system font as special case. This ensures that we preserve
  // the specific metrics of the standard system font as closely as possible.
  if ([familyName isEqual:defaultFontFamily] || [familyName isEqualToString:@"System"]) {
    font = cachedSystemFont(fontSize, fontWeight);
    if (font) {
      didFindFont = YES;

      if (isItalic || isCondensed) {
        UIFontDescriptor *fontDescriptor = [font fontDescriptor];
        UIFontDescriptorSymbolicTraits symbolicTraits = fontDescriptor.symbolicTraits;
        if (isItalic) {
          symbolicTraits |= UIFontDescriptorTraitItalic;
        }
        if (isCondensed) {
          symbolicTraits |= UIFontDescriptorTraitCondensed;
        }
        fontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
        font = [UIFont fontWithDescriptor:fontDescriptor size:fontSize];
      }
    }
  }

  // Gracefully handle being given a font name rather than font family, for
  // example: "Helvetica Light Oblique" rather than just "Helvetica".
  if (!didFindFont && [UIFont fontNamesForFamilyName:familyName].count == 0) {
    font = [UIFont fontWithName:familyName size:fontSize];
    if (font) {
      // It's actually a font name, not a font family name,
      // but we'll do what was meant, not what was said.
      familyName = font.familyName;
      fontWeight = weight ? fontWeight : weightOfFont(font);
      isItalic = style ? isItalic : isItalicFont(font);
      isCondensed = isCondensedFont(font);
    } else {
      // Not a valid font or family
      ABI10_0_0RCTLogError(@"Unrecognized font family '%@'", familyName);
      if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)]) {
        font = [UIFont systemFontOfSize:fontSize weight:fontWeight];
      } else if (fontWeight > UIFontWeightRegular) {
        font = [UIFont boldSystemFontOfSize:fontSize];
      } else {
        font = [UIFont systemFontOfSize:fontSize];
      }
    }
  }

  // Get the closest font that matches the given weight for the fontFamily
  CGFloat closestWeight = INFINITY;
  for (NSString *name in [UIFont fontNamesForFamilyName:familyName]) {
    UIFont *match = [UIFont fontWithName:name size:fontSize];
    if (isItalic == isItalicFont(match) &&
        isCondensed == isCondensedFont(match)) {
      CGFloat testWeight = weightOfFont(match);
      if (ABS(testWeight - fontWeight) < ABS(closestWeight - fontWeight)) {
        font = match;
        closestWeight = testWeight;
      }
    }
  }

  // Apply font variants to font object
  if (variant) {
    NSArray *fontFeatures = [ABI10_0_0RCTConvert ABI10_0_0RCTFontVariantDescriptorArray:variant];
    UIFontDescriptor *fontDescriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{
      UIFontDescriptorFeatureSettingsAttribute: fontFeatures
    }];
    font = [UIFont fontWithDescriptor:fontDescriptor size:fontSize];
  }

  return font;
}

+ (UIFont *)updateFont:(UIFont *)font withFamily:(NSString *)family
{
  return [self updateFont:font withFamily:family size:nil weight:nil style:nil variant:nil scaleMultiplier:1];
}

+ (UIFont *)updateFont:(UIFont *)font withSize:(NSNumber *)size
{
  return [self updateFont:font withFamily:nil size:size weight:nil style:nil variant:nil scaleMultiplier:1];
}

+ (UIFont *)updateFont:(UIFont *)font withWeight:(NSString *)weight
{
  return [self updateFont:font withFamily:nil size:nil weight:weight style:nil variant:nil scaleMultiplier:1];
}

+ (UIFont *)updateFont:(UIFont *)font withStyle:(NSString *)style
{
  return [self updateFont:font withFamily:nil size:nil weight:nil style:style variant:nil scaleMultiplier:1];
}

@end