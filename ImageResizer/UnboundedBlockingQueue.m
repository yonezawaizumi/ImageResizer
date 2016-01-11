//
//  UnboundedBlockingQueue.m
//  ImageResizer
//
//  Created by yonezawaizumi on 2016/01/03.
//  Copyright © 2016年 よねざわいずみ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pthread.h>
#import <sys/time.h>
#import "UnboundedBlockingQueue.h"

@interface UnboundedBlockingQueueNode : NSObject
@property (nonatomic, strong) id data;
@property (nonatomic, strong) UnboundedBlockingQueueNode* next;
@end

@implementation UnboundedBlockingQueueNode
@end

@interface UnboundedBlockingQueue ()

@property (nonatomic, strong, readwrite) UnboundedBlockingQueueNode *finalizer;
@property (nonatomic, assign) pthread_mutex_t lock;
@property (nonatomic, assign) pthread_cond_t notEmpty;
@property (nonatomic, strong) UnboundedBlockingQueueNode *first;
@property (nonatomic, strong) UnboundedBlockingQueueNode *last;

@end

@implementation UnboundedBlockingQueue

- (UnboundedBlockingQueue*) init {
    if ((self = [super init])) {
        self.last = nil;
        self.first = nil;
        self.finalizer = [[UnboundedBlockingQueueNode alloc] init];
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_notEmpty, NULL);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
    pthread_cond_destroy(&_notEmpty);
}

- (void)put: (id)data {
    pthread_mutex_lock(&_lock);
    
    if (self.first != self.finalizer) {
    
        UnboundedBlockingQueueNode *n = [[UnboundedBlockingQueueNode alloc] init];
        
        n.data = data;
        
        if (self.last != nil) {
            self.last.next = n;
        }
        if (self.first == nil) {
            self.first = n;
        }
        
        self.last = n;

        pthread_cond_signal(&_notEmpty);
    }
    
    pthread_mutex_unlock(&_lock);
}

- (void)shutdown {
    pthread_mutex_lock(&_lock);
    
    if (self.first != self.finalizer) {
        [self clearUnsafe];
        self.first = self.last = self.finalizer;
        pthread_cond_signal(&_notEmpty);
    }
    
    pthread_mutex_unlock(&_lock);
}

- (void)clearUnsafe {
    UnboundedBlockingQueueNode* n = self.first;
    while (n) {
        UnboundedBlockingQueueNode* next = n.next;
        n.data = nil;
        n.next = nil;
        n = next;
    }
    self.first = self.last = nil;
}

- (id)take: (int) timeout {
    id data = nil;
    struct timespec ts;
    struct timeval now;
    
    pthread_mutex_lock(&_lock);
    
    gettimeofday(&now, NULL);
    
    ts.tv_sec = now.tv_sec + timeout;
    ts.tv_nsec = 0;
    
    while (self.first == nil) {
        if (pthread_cond_timedwait(&_notEmpty, &_lock, &ts) == ETIMEDOUT) {
            pthread_mutex_unlock(&_lock);
            return nil;
        }
    }
    if (self.first == self.finalizer) {
        data = self.finalizer;
        [self clearUnsafe];
    } else {
        data = self.first.data;
        self.first = self.first.next;
        if (self.first == nil) {
            self.last = nil; //Empty queue
        }
    }
        
    pthread_mutex_unlock(&_lock);
    
    return data;
}

@end