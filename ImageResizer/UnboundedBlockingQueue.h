//
//  UnboundBlockingQueue.h
//  ImageResizer
//
//  Created by yonezawaizumi on 2016/01/03.
//  Copyright © 2016年 よねざわいずみ. All rights reserved.
//

#ifndef UnboundBlockingQueue_h
#define UnboundBlockingQueue_h

@class UnboundedBlockingQueueNode;

@interface UnboundedBlockingQueue : NSObject

- (UnboundedBlockingQueue*)init;
- (void)put: (id)data;
- (void)shutdown;
- (id)take: (int) timeout; //timeout is in seconds

@property (nonatomic, strong, readonly) UnboundedBlockingQueueNode *finalizer;

@end

#endif /* UnboundBlockingQueue_h */
