//
//  PhotoData.h
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/02.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface PhotoData : NSObject

@property(nonatomic, strong) UIImage *image;
@property(nonatomic, strong) UIImage *thumbnail;
@property(nonatomic, assign) CGSize originalSize;
@property(nonatomic, assign) NSInteger longSideLength;
@property(nonatomic, strong) NSMutableDictionary *metadata;
@property(nonatomic, strong) NSString *dateString;
@property(nonatomic, strong) CLLocation *location;
@property(nonatomic, strong) NSString *placement;

@end
