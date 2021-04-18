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
#import <Photos/Photos.h>
#import <Social/Social.h>
#import <UniformTypeIdentifiers/UTType.h>
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
@property(strong, nonatomic) id modalView;
@property(nonatomic, assign) BOOL dirty;
@property(nonatomic, assign) BOOL initial;

@end

enum {
    AlertClearAll = 1,
    AlertSaved = 2,
    AlertMailDisabled = 3,
    AlertDenied = 4,
};

enum {
    Image = 1,
    Title = 2,
    Subtitle = 3,
};

@implementation TableViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.initial = YES;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.initial = YES;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.initial = YES;
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.initial = YES;
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
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(ApplicationDidEnterBackground)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
}

- (void)ApplicationDidEnterBackground
{
    if (self.modalView) {
        if ([self.modalView isKindOfClass:[UIAlertController class]]) {
            [(UIAlertController *)self.modalView dismissViewControllerAnimated:YES completion:nil];
        } else if([self.modalView isKindOfClass:[QBImagePickerController class]]) {
            [(QBImagePickerController *)self.modalView dismissViewControllerAnimated:NO completion:nil];
        }
        self.modalView = nil;
    }
    
}

- (void)applicationDidBecomeActive
{
    if (!self.photoData.count && !self.initial) {
        [self showPicker:nil];
    }
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateButtons];
    if (self.initial) {
        self.initial = NO;
        [self showPicker:nil];
    }
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
    [self savePhotos:@selector(onSavedPhotos) inAlbum:TRUE];
}

- (void)onSavedPhotos
{
    self.tableView.userInteractionEnabled = YES;
    [self updateButtons];
    int failed = [self failedCount];
    int succeeded = [self succeededCount];
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        self.modalView = nil;
        [self showPicker:nil];
    }]];
    self.modalView = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sendMail:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *leaveMailPhotos = [userDefaults objectForKey:USER_DEFAULTS_KEY_LEAVE_MAIL_PHOTOS];
    
    [self savePhotos:@selector(onSavedPhotosForSendMail) inAlbum:leaveMailPhotos && [leaveMailPhotos boolValue]];
}

- (void)onSavedPhotosForSendMail
{
    int failed = [self failedCount];
    if (failed) {
        self.tableView.userInteractionEnabled = YES;
        [self updateButtons];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Failed", nil)
                                                                       message:[NSString stringWithFormat:NSLocalizedString(@"Failed %d Resizing", nil), failed]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            self.modalView = nil;
        }]];
        self.modalView = alert;
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if (![MFMailComposeViewController canSendMail]) {
        self.tableView.userInteractionEnabled = YES;
        [self updateButtons];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Cannot Send Mail", nil)
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            self.modalView = nil;
            [self updateButtons];
        }]];
        self.modalView = alert;
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    mailViewController.mailComposeDelegate = self;
    
    [mailViewController setMessageBody:@"" isHTML:NO];
    
    int index = 0;
    for (PhotoData *photoData in self.photoData) {
        [mailViewController addAttachmentData:photoData.resizedImageData ? photoData.resizedImageData : photoData.originalImageData
                                     mimeType:photoData.resizedImageData ? @"image/jpeg" : photoData.originalMimeType
                                     fileName:[NSString stringWithFormat:@"Image%d.jpg", ++index]];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:mailViewController animated:YES completion:nil];
    });
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    BOOL showPicker = NO;
    switch (result) {
        case MFMailComposeResultCancelled:
            break;
        default:
            [self clearAll:nil];
            showPicker = YES;
            break;
    }
    [controller dismissViewControllerAnimated:YES completion:nil];
    self.tableView.userInteractionEnabled = YES;
    [self updateButtons];
    if (showPicker) {
        [self showPicker:nil];
    }
}

- (void)createTemporaryAlbumWithCompletionHandler:(void (^)(PHAssetCollection *albim))handler
{
    NSString *albumTitle = NSLocalizedString(@"Image Resizer Shrinked Photos", "");
    PHFetchOptions *options = [PHFetchOptions new];
    options.predicate = [NSPredicate predicateWithFormat:@"localizedTitle == %@", albumTitle];
    PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
    
    if (albums.count > 0) {
        // Album is exist
        handler(albums[0]);
    } else {
        // Create new album.
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumTitle];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"Error creating AssetCollection: %@", error);
                handler(nil);
            } else {
                PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
                handler(albums[0]);
            }
        }];
    }
}

- (void)savePhotos:(SEL)selector inAlbum:(BOOL)inAlbum
{
    self.tableView.userInteractionEnabled = NO;
    [self updateButtons];
    
    NSString *tempPath;
    NSURL *tempUrl;
    if (inAlbum) {
        tempPath = [NSString stringWithFormat:@"%@ImageResizer.jpg", NSTemporaryDirectory()];
        tempUrl = [NSURL fileURLWithPath:tempPath];
    } else {
        tempPath = nil;
        tempUrl = nil;
    }
    
    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSMutableArray *sizes = [NSMutableArray arrayWithCapacity:self.photoData.count];
    for (PhotoData *photoData in self.photoData) {
        [sizes addObject:[NSValue valueWithCGSize:[sizeManager resizedSizeWithLongSideLength:photoData.longSideLength originalSize:photoData.originalSize]]];
    }

    const int count = (int)self.photoData.count;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block PHAssetCollection *album;
        if (inAlbum) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [self createTemporaryAlbumWithCompletionHandler:^(PHAssetCollection *tempAlbum) {
                album = tempAlbum;
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
        for (int index = 0; index < count; ++index) {
            PhotoData *photoData = self.photoData[index];
            if (photoData.longSideLength < 0) {
                continue;
            }
            CGSize size = [sizes[index] CGSizeValue];
            CGImageRef imageRef = [self prepareResizedImage:photoData size:size];

            NSDictionary *metadata = [self prepareResizedMetadata:photoData size:size];
            NSMutableData *data = [[NSMutableData alloc] init];
            CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, kUTTypeJPEG, 1, NULL);
            CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)metadata);
            CGImageDestinationFinalize(dest);
            CFRelease(dest);
            CFRelease(imageRef);
            photoData.resizedImageData = data;

            if (inAlbum) {
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [data writeToFile:tempPath atomically: NO];
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    // Create PHAsset from temporary file
                    PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:tempUrl];
                    PHObjectPlaceholder *assetPlaceholder = assetChangeRequest.placeholderForCreatedAsset;
                    //NSLog(@"%@", assetPlaceholder.localIdentifier);
                    // Add PHAsset to PHAssetCollection
                    PHAssetCollectionChangeRequest *assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
                    [assetCollectionChangeRequest addAssets:@[assetPlaceholder]];
                } completionHandler:^(BOOL success, NSError *error) {
                    if (!success) {
                        NSLog(@"creating Asset Error: %@", error);
                        photoData.resizedImageData = nil;
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }
        }
        [self performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
    });
}

- (int)failedCount
{
    int failed = 0;
    for (PhotoData *photoData in self.photoData) {
        if (!photoData.resizedImageData && photoData.longSideLength > 0) {
            ++failed;
        }
    }
    return failed;
}

- (int)succeededCount
{
    int succeeded = 0;
    for (PhotoData *photoData in self.photoData) {
        if (photoData.resizedImageData) {
            ++succeeded;
        }
    }
    return succeeded;
}

- (void)clearAll:(id)sender
{
    if (sender && self.dirty) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Clear All Resizing", nil)
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Abort", nil)
                                                  style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction *action) {
            self.modalView = nil;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Clear", nil)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            self.modalView = nil;
            [self clearAll:nil];
            [self showPicker:nil];
        }]];
        self.modalView = alert;
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        self.photoData = nil;
        [self updatePhotoData:nil];
    }
}

- (void)uniformSizes:(id)sender
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Uniform Sizes", nil)
                                                                   message:NSLocalizedString(@"Long Side", nil)
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [[SizeManager sharedInstance].longSideLengths enumerateObjectsUsingBlock:^(id lengthNumber, NSUInteger index, BOOL *stop) {
        NSInteger length = [(NSNumber *)lengthNumber intValue];
        NSString *label = length > 0 ? [NSString stringWithFormat:NSLocalizedString(@"%ld", nil), (long)length] : NSLocalizedString(@"Original", nil);
        [sheet addAction:[UIAlertAction actionWithTitle:label
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            for (PhotoData *photoData in self.photoData) {
                photoData.longSideLength = length;
            }
            [self checkDirty];
            self.modalView = nil;
            [self.tableView reloadData];
        }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        self.modalView = nil;
    }]];
    self.modalView = sheet;
    [self presentViewController:sheet animated:YES completion:nil];
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

- (void)showPicker:(id)sender
{
    if (self.modalView && [self.modalView isKindOfClass:[QBImagePickerController class]]) {
        return;
    }
    NSString *messageKey = nil;
    switch ([PHPhotoLibrary authorizationStatus]) {
        case PHAuthorizationStatusAuthorized:
            [self showPickerAnimated:sender != nil];
            break;
        case PHAuthorizationStatusLimited:
            messageKey = @"Photo Library Access Denied\n\n Please Allow Full Accessing At \"Settings - Privacy - Photos\"";
            break;
        case PHAuthorizationStatusRestricted:
            messageKey = @"Photo Library Access Denied\n\n Please Allow Accessing At \"Settings - General - Restrictions\"";
            break;
        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusNotDetermined:
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!self.modalView || ![self.modalView isKindOfClass:[QBImagePickerController class]]) {
                            [self showPickerAnimated:sender != nil];
                        }
                    });
                }
            }];
            break;
    }
    if (messageKey) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Denied", nil)
                                                                       message:messageKey
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            self.modalView = nil;
        }]];
        self.modalView = alert;
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showPickerAnimated:(BOOL)animated
{
	QBImagePickerController *imagePickerController = [QBImagePickerController new];
    imagePickerController.delegate = self;
    imagePickerController.mediaType = QBImagePickerMediaTypeImage;
    imagePickerController.allowsMultipleSelection = YES;
    imagePickerController.showsNumberOfSelectedAssets = YES;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *numberOfColumnsValue = [userDefaults objectForKey:USER_DEFAULTS_KEY_NUMBER_OF_COLUMNS];
    NSUInteger numberOfColumns = numberOfColumnsValue ? [numberOfColumnsValue integerValue] : DEFAULT_NUMBER_OF_COLUMNS;
    imagePickerController.numberOfColumnsInPortrait = numberOfColumns;
    CGSize size = self.view.frame.size;
    CGFloat ratio = size.width < size.height ? size.height / size.width : size.width / size.height;
    imagePickerController.numberOfColumnsInLandscape = (NSUInteger)(ratio * numberOfColumns + 0.5);
    imagePickerController.showFirstAlbumDirectly = YES;
    imagePickerController.minimumNumberOfSelection = 0;
    imagePickerController.maximumNumberOfSelection = MAXIMUM_IMAGES_COUNT;
    self.modalView = imagePickerController;
    [self presentViewController:imagePickerController animated:animated completion:nil];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets;
{
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:assets.count];

    SizeManager *sizeManager = [SizeManager sharedInstance];
    NSInteger defaultLongSideLength = sizeManager.defaultLongSideLength;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:NSLocalizedString(@"yyyy-MM-dd HH:mm:ss", nil)];

    PHImageManager *imageManager = [PHCachingImageManager new];
    
    for (int index = 0; index < assets.count; ++index) {
        PHAsset *asset = assets[index];
        PhotoData *photoData = [[PhotoData alloc] init];
        photoData.thumbnail = nil;
        photoData.image = nil;
        photoData.originalSize = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
        photoData.longSideLength = defaultLongSideLength;
        photoData.location = asset.location;
        NSDate *date = asset.creationDate;
        photoData.dateString = date ? [formatter stringFromDate:date] : NSLocalizedString(@"unknown datetime", nil);
        NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]];
        [imageManager requestImageForAsset:asset
                                targetSize:CGSizeMake(44, 44)
                               contentMode:PHImageContentModeDefault
                                   options:nil
                             resultHandler:^(UIImage *result, NSDictionary *info) {
                                 photoData.thumbnail = result;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
            });
        }];
        [imageManager requestImageDataAndOrientationForAsset:asset
                                                     options:nil
                                               resultHandler:^(NSData *imageData, NSString *dataUTI, CGImagePropertyOrientation orientation, NSDictionary * info) {
            photoData.originalImageData = imageData;
            photoData.originalMimeType = [UTType typeWithIdentifier:dataUTI].preferredMIMEType;
            CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nil);
            NSDictionary *metadata = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);
            if (metadata) {
                NSString *dateString = metadata[(NSString *)kCGImagePropertyExifDictionary][@"DateTimeOriginal"];
            if (dateString) {
                photoData.metadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
                photoData.dateString = [NSString stringWithFormat:NSLocalizedString(@"%@", nil), dateString];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                });
                }
            }
            CFRelease(imageSource);
            photoData.image = [UIImage imageWithData:imageData];
        }];
        /*NSDictionary *metadata = dict[@"metadata"];
        photoData.metadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
        NSString *dateString = photoData.metadata[(NSString *)kCGImagePropertyExifDictionary][@"DateTimeOriginal"];
        photoData.dateString = dateString
            ? [NSString stringWithFormat:NSLocalizedString(@"%@", nil), dateString]
            : NSLocalizedString(@"unknown datetime", nil);
        */
        [photos addObject:photoData];
    }
    
    [self updatePhotoData:photos];

    self.modalView = nil;
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    self.modalView = nil;
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
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
    UILabel *label = [cell viewWithTag:Title];
    label.text = [NSString stringWithFormat:NSLocalizedString(@"%hu x %hu -> %hu X %hu", nil),
                   (unsigned short)photoData.originalSize.width,
                   (unsigned short)photoData.originalSize.height,
                   (unsigned short)size.width,
                   (unsigned short)size.height];
    
    //NSLog(@"%@", photoData.metadata);
    label = [cell viewWithTag:Subtitle];
    label.text = photoData.dateString;
    UIImageView *imageView = [cell viewWithTag:Image];
    imageView.image = photoData.thumbnail ? photoData.thumbnail : [UIImage imageNamed:@"statusicon_notload"];
    
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
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipLast;//CGImageGetBitmapInfo(imageRef);
    CGColorSpaceRef colorSpaceInfo = CGImageGetColorSpace(imageRef);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
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
    // TODO: 壊れたデータを読んだ場合の対策が必要
    CGContextRef bitmap = CGBitmapContextCreate(NULL, size.width, size.height, bitsPerComponent, 0, colorSpaceInfo, bitmapInfo);
    
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
