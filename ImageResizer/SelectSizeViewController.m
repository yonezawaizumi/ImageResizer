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
@property(nonatomic, strong) UIImageView *imageView;

@end

enum {
    Image = 1,
    Title1 = 2,
    Title2 = 3,
    LatLng = 4,
    Placement = 5,
    Content = 99,
};

@implementation SelectSizeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.header = [[self.tableView dequeueReusableCellWithIdentifier:@"Header"] viewWithTag:Content];

    UIScrollView* scrollView = [self.header viewWithTag:Image];
    scrollView.delegate = self;
    scrollView.maximumZoomScale = 5.0;
    scrollView.minimumZoomScale = 1.0;
    self.imageView = [[UIImageView alloc] init];
    self.imageView.frame = CGRectMake(0, 0, scrollView.frame.size.width, scrollView.frame.size.height);
    [scrollView addSubview:self.imageView];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

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
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (!section)   return 0;
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
        [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.currentRow inSection:1]].accessoryType = UITableViewCellAccessoryNone;
        self.currentRow = row;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section)    return 0;
    return self.header.frame.size.height;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section)   return nil;
    self.imageView.image = self.photoData.image;

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
                NSString *result = [NSString stringWithFormat:@"%@%@%@%@",
                                    myPlacemark.administrativeArea,
                                    myPlacemark.locality,
                                    myPlacemark.thoroughfare,
                                    myPlacemark.subThoroughfare];
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

@end
