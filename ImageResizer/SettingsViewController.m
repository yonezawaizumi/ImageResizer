//
//  SettingsViewController.m
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/16.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import "SettingsViewController.h"
#import "Consts.h"

@interface SettingsViewController ()

@property(nonatomic, strong) UITableViewCell *leaveMailPhotosCell;

@end

enum {
    LeavePhotosTitle = 1,
    LeavePhotosSwitch = 2,
};

@implementation SettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)done:(id)sender
{
    if (self.delegate) {
        [self.delegate didFinishSettings:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)leaveMailPhotosSwitch:(id)sender
{
    BOOL leave = ((UISwitch *)sender).on;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[NSNumber numberWithBool:leave] forKey:USER_DEFAULTS_KEY_LEAVE_MAIL_PHOTOS];
    [self updateLeaveMailPhotosState:leave];
}

- (void)updateLeaveMailPhotosState:(BOOL)leave
{
    UILabel *label = (UILabel *)[self.leaveMailPhotosCell viewWithTag:LeavePhotosTitle];
    label.text = leave ? NSLocalizedString(@"Leave In Album", nil) : NSLocalizedString(@"Remove From Album", nil);
    UISwitch *on = (UISwitch *)[self.leaveMailPhotosCell viewWithTag:LeavePhotosSwitch];
    on.on = leave;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0:
            return 1;
        default:
            break;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return NSLocalizedString(@"Attached Photos In Mail", nil);
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    switch (indexPath.section) {
        case 0:
        {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSNumber *leaveMailPhotosValue = [userDefaults objectForKey:USER_DEFAULTS_KEY_LEAVE_MAIL_PHOTOS];
            BOOL leaveMailPhotos = leaveMailPhotosValue ? [leaveMailPhotosValue boolValue] : YES;
            if (!self.leaveMailPhotosCell) {
                self.leaveMailPhotosCell = [tableView dequeueReusableCellWithIdentifier:@"LeaveMailPhotos" forIndexPath:indexPath];
            }
            cell = self.leaveMailPhotosCell;
            [self updateLeaveMailPhotosState:leaveMailPhotos];
            break;
        }
        default:
            break;
    }
    
    // Configure the cell...
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
