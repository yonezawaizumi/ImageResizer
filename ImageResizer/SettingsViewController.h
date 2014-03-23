//
//  SettingsViewController.h
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/16.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SettingsViewController;

@protocol SettingsViewControllerDelegate

- (void)didFinishSettings:(SettingsViewController *)settingViewController;

@end

@interface SettingsViewController : UITableViewController

@property(nonatomic, assign) id<SettingsViewControllerDelegate> delegate;
- (IBAction)done:(id)sender;
- (IBAction)leaveMailPhotosSwitch:(id)sender;

@end
