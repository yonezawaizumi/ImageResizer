//
//  SizeManager.m
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/02.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import "SizeManager.h"
#import "Consts.h"

@interface SizeManager ()

@property(nonatomic, strong, readwrite) NSArray *longSideLengths;

@end

@implementation SizeManager

+ (SizeManager *)sharedInstance
{
    static SizeManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SizeManager alloc] initSharedInstance];
    });
    return instance;
}

- (SizeManager *)initSharedInstance
{
    self = [super init];
    if (self) {
        NSInteger lengths[] = RESIZED_LONG_SIDE_LENGTHS;
        NSInteger count = sizeof (lengths) / sizeof (lengths[0]);
        NSMutableArray *ary = [NSMutableArray arrayWithCapacity:count];
        for (int i = 0; i < count; ++i) {
            [ary addObject:[NSNumber numberWithInteger:lengths[i]]];
        }
        self.longSideLengths = ary;
    }
    return self;
}

- (CGSize)resizedSizeWithLongSideLength:(NSInteger)longSideLength originalSize:(CGSize)originalSize;
{
    for (NSNumber *length in self.longSideLengths) {
        NSInteger len = [length integerValue];
        if (longSideLength <= len) {
            longSideLength = len;
            break;
        }
    }
    
    CGSize resizedSize;
    if (originalSize.width > originalSize.height) {
        resizedSize.width = longSideLength;
        resizedSize.height = (NSInteger)(originalSize.height * longSideLength / originalSize.width);
    } else {
        resizedSize.height = longSideLength;
        resizedSize.width = (NSInteger)(originalSize.width * longSideLength / originalSize.height);
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:longSideLength] forKey:USER_DEFAULTS_KEY_DEFAULT_RESIZED_LONG_SIZE_LENGTH];
    
    return resizedSize;
}

- (NSInteger)defaultLongSideLength
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *longSideLength = [defaults objectForKey:USER_DEFAULTS_KEY_DEFAULT_RESIZED_LONG_SIZE_LENGTH];
    if (longSideLength) {
        return [longSideLength integerValue];
    } else {
        NSInteger longSideLengthValue = DEFAULT_RESIZED_LONG_SIDE_LENGTH;
        [defaults setObject:[NSNumber numberWithInteger:longSideLengthValue] forKey:USER_DEFAULTS_KEY_DEFAULT_RESIZED_LONG_SIZE_LENGTH];
        return longSideLengthValue;
    }
}


@end
