//
//  SelectSizeViewController.h
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/01.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PhotoData.h"

@protocol SelectSizeViewControllerDelegate

- (void)didSelectLongSideLength:(NSInteger)longSideLength photoData:(PhotoData *)photoData;

@end

@interface SelectSizeViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) IBOutlet UITableView *tableView;
@property(nonatomic, strong) PhotoData *photoData;
@property(nonatomic, weak) id<SelectSizeViewControllerDelegate> delegate;

@end
