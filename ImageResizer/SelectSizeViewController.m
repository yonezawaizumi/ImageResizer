//
//  SelectSizeViewController.m
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/01.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import "SelectSizeViewController.h"
#import "SizeManager.h"

@interface SelectSizeViewController ()

@property(nonatomic, assign) NSInteger currentRow;
@property(nonatomic, strong) UIView *header;

@end

enum {
    Image = 1,
    Title1 = 2,
    Title2 = 3,
    LatLng = 4,
    Placement = 5,
};

@implementation SelectSizeViewController


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.currentRow = -1;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.tableView flashScrollIndicators];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSInteger longSideLength = [sizeManager.longSideLengths[self.currentRow] integerValue];
    [self.delegate didSelectLongSideLength:longSideLength photoData:self.photoData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.photoData = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SizeManager *sizeManager = [SizeManager sharedInstance];
    return sizeManager.longSideLengths.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Size Picker";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSInteger longSideLength = [sizeManager.longSideLengths[indexPath.row] integerValue];
    CGSize resizedSize = [sizeManager resizedSizeWithLongSideLength:longSideLength originalSize:self.photoData.originalSize];
    cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%hu x %hu", nil),
                           (unsigned short)resizedSize.width,
                           (unsigned short)resizedSize.height];
    if (self.currentRow < 0 && longSideLength == self.photoData.longSideLength) {
        self.currentRow = indexPath.row;
    }
    cell.accessoryType = indexPath.row == self.currentRow ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    if (row != self.currentRow) {
        [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
        [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.currentRow inSection:0]].accessoryType = UITableViewCellAccessoryNone;
        self.currentRow = row;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (!self.header) {
        self.header = [tableView dequeueReusableCellWithIdentifier:@"Header"];
    }
    return self.header.frame.size.height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIImageView *imageView = (UIImageView *)[self.header viewWithTag:Image];
    imageView.image = self.photoData.image;

    UILabel *label = (UILabel *)[self.header viewWithTag:Title1];
    label.text = [NSString stringWithFormat:NSLocalizedString(@"%hu x %hu", nil),
                  (unsigned short)self.photoData.originalSize.width,
                  (unsigned short)self.photoData.originalSize.height];

    label = (UILabel *)[self.header viewWithTag:Title2];
    label.text = self.photoData.dateString;;

    CLLocation *location = self.photoData.location;
    label = (UILabel *)[self.header viewWithTag:LatLng];
    label.text = location ? [NSString stringWithFormat:NSLocalizedString(@"%.4f / %.4f", nil),
                             location.coordinate.latitude,
                             location.coordinate.longitude]
                           : NSLocalizedString(@"unknown location", nil);

    [self setPlacement];
    if (location && !self.photoData.placement) {
        CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
        [geoCoder reverseGeocodeLocation:location completionHandler:^(NSArray* placemarks, NSError* error){
            if ([placemarks count] > 0){
                CLPlacemark *myPlacemark = [placemarks objectAtIndex:0];
                NSArray *address = [myPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"];
                NSString *result = [address componentsJoinedByString:@""];
                NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"^(?:〒\\d{3}-\\d{4}\\s+|\\d{7}\\s+)?(.+)"
                                                                                        options:0
                                                                                          error:nil];
                NSTextCheckingResult *match = [regexp firstMatchInString:result options:0 range:NSMakeRange(0, result.length)];
                if(match.numberOfRanges > 0) {
                    result = [result substringWithRange:[match rangeAtIndex:1]];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.photoData) {
                        self.photoData.placement = result;
                        [self setPlacement];
                    }
                });
            }
        }];
    }
    
    return self.header;
}

- (void)setPlacement
{
    UILabel *label = (UILabel *)[self.header viewWithTag:Placement];
    label.text = self.photoData.placement ? self.photoData.placement : @"";
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
