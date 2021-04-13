//
//  TableViewController.h
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/01.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "QBImagePicker/QBImagePicker.h"
#import "SelectSizeViewController.h"


@interface TableViewController : UITableViewController<UITableViewDataSource, UITableViewDelegate, QBImagePickerControllerDelegate, SelectSizeViewControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate>

@property(nonatomic, strong) IBOutlet UIBarButtonItem *organizeButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *clearAllButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *uniformSizesButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *sendMailButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *saveButton;
@property(nonatomic, strong) IBOutlet UIBarButtonItem *settingsButton;

- (IBAction)showPicker:(id)sender;
- (IBAction)clearAll:(id)sender;
- (IBAction)uniformSizes:(id)sender;
- (IBAction)save:(id)sender;
- (IBAction)sendMail:(id)sender;

@end
