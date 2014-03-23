//
//  SizeManager.h
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/02.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SizeManager : NSObject

+ (SizeManager *)sharedInstance;

- (CGSize)resizedSizeWithLongSideLength:(NSInteger)longSideLength originalSize:(CGSize)originalSize;

@property(nonatomic, strong, readonly) NSArray *longSideLengths;
@property(nonatomic, assign, readonly) NSInteger defaultLongSideLength;


@end
