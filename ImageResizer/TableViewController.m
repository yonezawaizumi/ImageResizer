//
//  TableViewController.m
//  ImageResizer
//
//  Created by よねざわいずみ on 2014/01/01.
//  Copyright (c) 2014年 よねざわいずみ. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "AppDelegate.h"
#import "TableViewController.h"
#import "SelectSizeViewController.h"
#import "SizeManager.h"
#import "PhotoData.h"
#import "Consts.h"

#if !defined(RADIANS)
#define RADIANS(D) (D * M_PI / 180)
#endif

@interface TableViewController ()

@property(nonatomic, strong) NSMutableArray *photoData;
@property(nonatomic, assign) BOOL dirty;

@end

enum {
    AlertClearAll = 1,
    AlertSaved = 2,
    AlertMailDisabled = 3,
};

@implementation TableViewController

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

    self.photoData = nil;
    self.dirty = NO;
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateButtons];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self updateButtons];
}

- (void)save:(id)sender
{
    [self savePhotos:@selector(onSavedPhotosWithURLs:) toAssetsLibrary:YES];
}

- (void)onSavedPhotosWithURLs:(NSArray *)URLs
{
    self.tableView.userInteractionEnabled = YES;
    [self updateButtons];
    int failed = [self failedCountFronURLs:URLs];
    int succeeded = (int)URLs.count - failed;
    NSString *title;
    NSString *message;
    if (failed) {
        title = NSLocalizedString(@"Failed", nil);
        message = [NSString stringWithFormat:NSLocalizedString(@"Failed %d Resizing", nil), failed];
    } else {
        [self clearAll:nil];
        title = NSLocalizedString(@"Succeeded", nil);
        message = [NSString stringWithFormat:NSLocalizedString(@"Resized %d Photos", nil), succeeded];
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    alert.tag = AlertSaved;
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    appDelegate.modalView = alert;
    appDelegate.modalViewCancelIndex = 0;
    [alert show];
}

- (void)sendMail:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *leaveMailPhotos = [userDefaults objectForKey:USER_DEFAULTS_KEY_LEAVE_MAIL_PHOTOS];
    
    [self savePhotos:@selector(onSavedPhotosForSendMailWithURLs:) toAssetsLibrary:leaveMailPhotos && [leaveMailPhotos boolValue]];
}

- (void)onSavedPhotosForSendMailWithURLs:(NSArray *)URLs
{
    int failed = [self failedCountFronURLs:URLs];
    if (failed) {
        self.tableView.userInteractionEnabled = YES;
        [self updateButtons];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed", nil)
                                                        message:[NSString stringWithFormat:NSLocalizedString(@"Failed %d Resizing", nil), failed]
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        alert.tag = AlertSaved;
        AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
        appDelegate.modalView = alert;
        appDelegate.modalViewCancelIndex = 0;
        [alert show];
        return;
    }
    
    if (![MFMailComposeViewController canSendMail]) {
        self.tableView.userInteractionEnabled = YES;
        [self updateButtons];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Send Mail", nil)
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        alert.tag = AlertMailDisabled;
        AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
        appDelegate.modalView = alert;
        appDelegate.modalViewCancelIndex = 0;
        [alert show];
    }
    
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    mailViewController.mailComposeDelegate = self;
    
    [mailViewController setMessageBody:@"" isHTML:NO];
    
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    failed = 0;
    const int count = (int)URLs.count;
    const BOOL leaveMailPhots = count && [URLs[0] isKindOfClass:[NSData class]];
    dispatch_semaphore_t finishedSemaphore = dispatch_semaphore_create(1);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int index = 0; index < count; ++index) {
            if (leaveMailPhots) {
                [mailViewController addAttachmentData:URLs[index]
                                             mimeType:@"image/jpeg"
                                             fileName:[NSString stringWithFormat:@"Image%d.jpg", index]];
            } else {
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [assetsLibrary assetForURL:URLs[index]
                               resultBlock:^(ALAsset *asset) {
                                   ALAssetRepresentation *representation = [asset defaultRepresentation];
                                   NSUInteger size = (NSUInteger)[representation size];
                                   void *buff = malloc(size);
                                   if (buff) {
                                       NSError *error = nil;
                                       NSUInteger bytesRead = [representation getBytes:buff fromOffset:0 length:size error:&error];
                                       dispatch_semaphore_wait(finishedSemaphore, DISPATCH_TIME_FOREVER);
                                       if (bytesRead && !error) {
                                           NSData *photo = [NSData dataWithBytesNoCopy:buff length:bytesRead freeWhenDone:YES];
                                           [mailViewController addAttachmentData:photo
                                                                        mimeType:@"image/jpeg"
                                                                        fileName:[NSString stringWithFormat:@"Image%d.jpg", index]];
                                       } else {
                                           free(buff);
                                       }
                                       if (error) {
                                           NSLog(@"error:%@", error);
                                       }
                                       dispatch_semaphore_signal(finishedSemaphore);
                                       dispatch_semaphore_signal(semaphore);
                                   }
                               }
                              failureBlock:^(NSError *error){
                                  NSLog(@"error:%@", error);
                                  dispatch_semaphore_signal(semaphore);
                              }
                ];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }
        }
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:mailViewController animated:YES completion:nil];
    });
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result) {
        case MFMailComposeResultCancelled:
            break;
        default:
            [self clearAll:nil];
            break;
    }
    [controller dismissViewControllerAnimated:YES completion:nil];
    self.tableView.userInteractionEnabled = YES;
    [self updateButtons];
}

- (void)savePhotos:(SEL)selector toAssetsLibrary:(BOOL)toAssetsLibrary
{
    self.tableView.userInteractionEnabled = NO;
    [self updateButtons];
    
    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSMutableArray *sizes = [NSMutableArray arrayWithCapacity:self.photoData.count];
    for (PhotoData *photoData in self.photoData) {
        [sizes addObject:[NSValue valueWithCGSize:[sizeManager resizedSizeWithLongSideLength:photoData.longSideLength originalSize:photoData.originalSize]]];
    }
    ALAssetsLibrary *assetsLibrary = toAssetsLibrary ? [[ALAssetsLibrary alloc] init] : nil;
    //NSString *fileNameBase = [NSString stringWithFormat:@"%lx_", (long)[NSDate date].timeIntervalSince1970];

    const int count = (int)self.photoData.count;
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity:count];
    dispatch_semaphore_t finishedSemaphore = dispatch_semaphore_create(1);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int index = 0; index < count; ++index) {
            PhotoData *photoData = self.photoData[index];
            CGSize size = [sizes[index] CGSizeValue];
            CGImageRef imageRef = [self prepareResizedImage:photoData size:size];
            NSDictionary *metadata = [self prepareResizedMetadata:photoData size:size];
            if (toAssetsLibrary) {
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [assetsLibrary writeImageToSavedPhotosAlbum:imageRef
                                                   metadata:metadata
                                            completionBlock:^(NSURL *assetURL, NSError *error) {
                                                //NSLog(@"inde:%d", index);
                                                //NSLog(@"URL:%@", assetURL);
                                                dispatch_semaphore_wait(finishedSemaphore, DISPATCH_TIME_FOREVER);
                                                if(error) {
                                                    NSLog(@"error:%@", error);
                                                    [URLs addObject:[NSNull null]];
                                                } else {
                                                    [URLs addObject:assetURL];
                                                }
                                                dispatch_semaphore_signal(finishedSemaphore);
                                                CFRelease(imageRef);
                                                dispatch_semaphore_signal(semaphore);
                                            }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            } else {
                NSMutableData *data = [[NSMutableData alloc] init];
                CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, kUTTypeJPEG, 1, NULL);
                CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)metadata);
                CGImageDestinationFinalize(dest);
                CFRelease(dest);
                [URLs addObject:data];
            }
        }
        [self performSelectorOnMainThread:selector withObject:URLs waitUntilDone:NO];
    });
}

- (int)failedCountFronURLs:(NSArray*)URLs
{
    int failed = 0;
    for (id URL in URLs) {
        if ([URL isKindOfClass:[NSNull class]]) {
            ++failed;
        }
    }
    return failed;
}

- (void)clearAll:(id)sender
{
    if (sender && self.dirty) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Clear All Resizing", nil)
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Abort", nil)
                                              otherButtonTitles:NSLocalizedString(@"Clear", nil), nil];
        alert.tag = AlertClearAll;
        AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
        appDelegate.modalView = alert;
        appDelegate.modalViewCancelIndex = 0;
        [alert show];
    } else {
        self.photoData = nil;
        [self updatePhotoData:nil];
    }
}

- (void)uniformSizes:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Uniform Long Side Sizes", nil)
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    for (NSNumber *length in [SizeManager sharedInstance].longSideLengths) {
        [sheet addButtonWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@", nil), length]];
    }
    [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    appDelegate.modalView = sheet;
    appDelegate.modalViewCancelIndex = self.photoData.count;
    [sheet showFromBarButtonItem:self.uniformSizesButton animated:YES];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    ((AppDelegate *)[UIApplication sharedApplication].delegate).modalView = nil;
    NSArray *sizes = [SizeManager sharedInstance].longSideLengths;
    if (buttonIndex < sizes.count) {
        NSInteger longSideLength = [sizes[buttonIndex] integerValue];
        for (PhotoData *photoData in self.photoData) {
            photoData.longSideLength = longSideLength;
        }
        [self checkDirty];
        [self.tableView reloadData];
    }
}

- (void)updatePhotoData:(NSMutableArray *)photoData
{
    if (photoData) {
        self.photoData = photoData;
    }
    self.dirty = NO;
    [self updateButtons];
    [self.tableView reloadData];
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    ((AppDelegate *)[UIApplication sharedApplication].delegate).modalView = nil;
    switch(alertView.tag) {
        case AlertClearAll:
            switch (buttonIndex) {
                case 0:
                    break;
                case 1:
                    [self clearAll:nil];
                    break;
            }
            break;
        case AlertMailDisabled:
            [self updateButtons];
            break;
    }
}

- (void)showPicker:(id)sender
{
	ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
    elcPicker.returnsOriginalImage = YES;
    elcPicker.imagePickerDelegate = self;
    elcPicker.maximumImagesCount = MAXIMUM_IMAGES_COUNT;
    [self presentViewController:elcPicker animated:YES completion:nil];
}

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:info.count];

    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSInteger defaultLongSideLength = sizeManager.defaultLongSideLength;
    
    for (NSDictionary *dict in info) {
        PhotoData *photoData = [[PhotoData alloc] init];
        photoData.thumbnail = dict[@"thumbnail"];
        photoData.image = dict[UIImagePickerControllerOriginalImage];
        photoData.originalSize = [photoData.image size];
        photoData.longSideLength = defaultLongSideLength;
        NSDictionary *metadata = dict[@"metadata"];
        photoData.metadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
        photoData.location = dict[ALAssetPropertyLocation];
        NSString *dateString = photoData.metadata[(NSString *)kCGImagePropertyExifDictionary][@"DateTimeOriginal"];
        photoData.dateString = dateString
            ? [NSString stringWithFormat:NSLocalizedString(@"%@", nil), dateString]
            : NSLocalizedString(@"unknown datetime", nil);

        [photos addObject:photoData];
    }
    
    [self updatePhotoData:photos];

    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Detail"] ) {
        SelectSizeViewController *selectSizeViewController = [segue destinationViewController];
        selectSizeViewController.delegate = self;
        selectSizeViewController.photoData = self.photoData[self.tableView.indexPathForSelectedRow.row];
    }
}

- (void)didSelectLongSideLength:(NSInteger)longSideLength photoData:(PhotoData *)photoData
{
    if (longSideLength && photoData.longSideLength != longSideLength) {
        photoData.longSideLength = longSideLength;
        [self checkDirty];
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        [self updateButtons];
    }
}

- (void)checkDirty
{
    NSInteger defaultLongSizeLength = [SizeManager sharedInstance].defaultLongSideLength;
    self.dirty = NO;
    for (PhotoData *photoData in self.photoData) {
        if (photoData.longSideLength != defaultLongSizeLength) {
            self.dirty = YES;
            break;
        }
    }
}

- (void)updateButtons
{
    BOOL userIntaractive = self.tableView.userInteractionEnabled;
    BOOL enabled = self.photoData.count > 0;
    if (userIntaractive) {
        self.navigationItem.rightBarButtonItem = enabled ? self.editButtonItem : self.organizeButton;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    enabled = enabled && userIntaractive && !self.editing;
    self.clearAllButton.enabled = enabled;
    self.uniformSizesButton.enabled = enabled;
    self.sendMailButton.enabled = enabled && [MFMailComposeViewController canSendMail];
    self.saveButton.enabled = enabled;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.photoData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Image";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    SizeManager *sizeManager = [SizeManager sharedInstance];
    
    PhotoData *photoData = self.photoData[indexPath.row];
    CGSize size = [sizeManager resizedSizeWithLongSideLength:photoData.longSideLength originalSize:photoData.originalSize];
    cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%hu x %hu -> %hu X %hu", nil),
                           (unsigned short)photoData.originalSize.width,
                           (unsigned short)photoData.originalSize.height,
                           (unsigned short)size.width,
                           (unsigned short)size.height];
    
    //NSLog(@"%@", photoData.metadata);
    cell.detailTextLabel.text = photoData.dateString;
    cell.imageView.image = photoData.thumbnail;
    
    //NSLog(@"%@", photoData.location);
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.photoData removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    PhotoData *photoData = self.photoData[fromIndexPath.row];
    [self.photoData removeObjectAtIndex:fromIndexPath.row];
    [self.photoData insertObject:photoData atIndex:toIndexPath.row];
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}

- (CGImageRef)prepareResizedImage:(PhotoData *)photoData size:(CGSize)size
{
    NSInteger orientation = [photoData.metadata[@"Orientation"] integerValue];
    CGImageRef imageRef = [photoData.image CGImage];
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGColorSpaceRef colorSpaceInfo = CGImageGetColorSpace(imageRef);
    
/*
        UIImageOrientationUp,            // default orientation
        UIImageOrientationDown,          // 180 deg rotation
        UIImageOrientationLeft,          // 90 deg CCW
        UIImageOrientationRight,         // 90 deg CW
        UIImageOrientationUpMirrored,    // as above but image mirrored along other axis. horizontal flip
        UIImageOrientationDownMirrored,  // horizontal flip
        UIImageOrientationLeftMirrored,  // vertical flip
        UIImageOrientationRightMirrored, // vertical flip
 Orientation	どう補正すれば正しい向きになるか
 1	そのまま
 2	上下反転(上下鏡像?)
 3	180度回転
 4	左右反転
 5	上下反転、時計周りに270度回転
 6	時計周りに90度回転
 7	上下反転、時計周りに90度回転
 8	時計周りに270度回転
 */
    CGContextRef bitmap = CGBitmapContextCreate(NULL, size.width, size.height, CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef), colorSpaceInfo, bitmapInfo);
    
    CGFloat w, h;
    switch (orientation) {
        case 0:
        case 1:
            w = size.width;
            h = size.height;
            break;
        case 3:
            w = size.width;
            h = size.height;
            CGContextTranslateCTM(bitmap, w, h);
            CGContextRotateCTM(bitmap, RADIANS(180));
            break;
        case 6:
            w = size.height;
            h = size.width;
            CGContextRotateCTM(bitmap, RADIANS(-90));
            CGContextTranslateCTM(bitmap, -w, 0);
            break;
        case 8:
            w = size.height;
            h = size.width;
            CGContextRotateCTM(bitmap, RADIANS(90));
            CGContextTranslateCTM(bitmap, 0, -h);
            break;
    }
    
    CGContextDrawImage(bitmap, CGRectMake(0, 0, w, h), imageRef);
    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
    
    CGContextRelease(bitmap);

    return newImageRef;
}

- (NSDictionary *)prepareResizedMetadata:(PhotoData *)photoData size:(CGSize)size
{
    const NSNumber *width = [NSNumber numberWithInt:size.width];
    const NSNumber *height = [NSNumber numberWithInt:size.height];
    const NSString *ExifKey = (NSString *)kCGImagePropertyExifDictionary;
    const NSString *GPSKey = (NSString *)kCGImagePropertyGPSDictionary;
    const NSDictionary *originalMetadata = photoData.metadata;
    //NSLog(@"%@", originalMetadata);
    
    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
    for (NSString *key in @[@"DPIWidth", @"DPIHeight", @"Depth"]) {
        id value = originalMetadata[key];
        if (value) {
            metadata[key] = value;
        }
    }
    metadata[@"ColorModel"] = @"RGB";
    metadata[@"Orientation"] = @1;
    metadata[@"PixelWidth"] = width;
    metadata[@"PixelHeight"] = height;
    
    NSMutableDictionary *Exif = [NSMutableDictionary dictionaryWithCapacity:4];
    Exif[@"PixelXDimension"] = width;
    Exif[@"PixelYDimension"] = height;
    NSDictionary *originalExif = originalMetadata[ExifKey];
    if (originalExif) {
        for (NSString *key in @[@"DateTimeOriginal", @"DateTimeDigitized"]) {
            id value = originalExif[key];
            if (value) {
                Exif[key] = value;
            }
        }
    }
    metadata[ExifKey] = Exif;
    id value = originalMetadata[GPSKey];
    if (value) {
        metadata[GPSKey] = value;
    }
    
    return metadata;
}

@end
