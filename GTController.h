//
//  GTController.h
//  GeoTag
//
//  Created by Marco S Hyman on 6/14/09.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "GTTableView.h"
#import "GTMapView.h"
#import "ImageInfo.h"

@interface GTController : NSObject {
    IBOutlet GTTableView *tableView;
    IBOutlet NSImageView *imageWell;
    IBOutlet GTMapView *mapView;
    IBOutlet NSProgressIndicator *progressIndicator;
    
    NSMutableArray *images;
    NSUndoManager *undoManager;
}

- (IBAction) showOpenPanel: (id) sender;
- (IBAction) saveLocations: (id) sender;
- (IBAction) revertToSaved: (id) sender;
- (IBAction) showPreferencePanel: (id) sender;

- (IBAction) clear: (id) sender;

- (NSProgressIndicator *) progressIndicator;
- (BOOL) isValidImageAtIndex: (NSInteger) ix;
- (ImageInfo *) imageAtIndex: (NSInteger) ix;
- (BOOL) addImageForPath: (NSString *) path;
- (void) showImageForIndex: (NSInteger) ix;
- (void) adjustMapViewForRow: (NSInteger) row;
- (void) updateLocationForImageAtRow: (NSInteger) row
			    latitude: (NSString *) lat
			   longitude: (NSString *) lng
			    modified: (BOOL) mod;

- (void) updateLatitude: (NSString *) lat
	      longitude: (NSString *) lng;

- (BOOL) isDuplicatePath: (NSString *) path;

@end
