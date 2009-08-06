//
//  ImageInfo.m
//  GeoTag
//
//  Created by Marco S Hyman on 6/15/09.
//

#import "ImageInfo.h"
#import "GTDefaultsController.h"

#if GTDEBUG == 0
#define NSLog(...)
#endif

@interface ImageInfo ()
- (BOOL) getInfoForFileAt: (NSString *) path;
@end

@implementation ImageInfo
@synthesize latitude;
@synthesize longitude;
@synthesize originalLatitude;
@synthesize originalLongitude;
@synthesize validImage;
@synthesize orientation;

#pragma mark -
#pragma mark Class methods

+ (id) imageInfoWithPath: (NSString *) path
{
    return [[self alloc] initWithPath: path];
}

#pragma mark -
#pragma mark init and property accessors

- (id) initWithPath: (NSString *) path
{
    self = [super init];
    if (self) {
	infoDict = [NSMutableDictionary dictionaryWithObject: path
						      forKey: IIPathName];
	[infoDict setObject: [path lastPathComponent] forKey: IIImageName];
	validImage = [self getInfoForFileAt: path];
	if (validImage) {
	    [self setOriginalLatitude: [self latitude]];
	    [self setOriginalLongitude: [self longitude]];
	}
	NSLog(@"Orientation %f", [self orientation]);
    }
    return self;
}

- (NSString *) path
{
    return [infoDict objectForKey: IIPathName];
}

- (NSString *) name
{
    return [infoDict objectForKey: IIImageName];
}

- (NSString *) date
{
    return [infoDict objectForKey: IIDateTime];
}

- (NSString *) latitudeAsString
{
    return [NSString stringWithFormat: @"%f", [self latitude]];
}

- (NSString *) longitudeAsString
{
    return [NSString stringWithFormat: @"%f", [self longitude]];
}

#pragma mark -
#pragma mark string representation methods

- (NSString *) stringRepresentation
{
    CGFloat lat, lng;
    
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if ((lat = [self latitude]) && (lng = [self longitude]))
	return [NSString stringWithFormat: @"%f %f", lat, lng];
    return @"";
}

- (BOOL) convertFromString: (NSString *) representation
		  latitude: (NSString **) lat
		 longitude: (NSString **) lng
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    double latAsDouble, lngAsDouble;
    NSScanner *scanner = [NSScanner scannerWithString: representation];
    if (! [scanner scanDouble: &latAsDouble] ||
	latAsDouble < -90.0 ||
	latAsDouble > 90.0) {
	NSLog(@"Bad lat: %f", latAsDouble);
	return NO;
    }
    if (! [scanner scanDouble: &lngAsDouble] ||
	lngAsDouble < -180.0 ||
	lngAsDouble > 180.0) {
	NSLog(@"Bad lng: %f", lngAsDouble);
	return NO;
    }
    if (! [scanner isAtEnd]) {
	NSLog(@"scanner not at end of string: %@", representation);
	return NO;
    }
    *lat = [NSString stringWithFormat: @"%f", latAsDouble];
    *lng = [NSString stringWithFormat: @"%f", lngAsDouble];
    NSLog(@"in: %@ out: %@, %@, scanned: %f, %f", representation, *lat, *lng,
	  latAsDouble, lngAsDouble);
    return YES;
}

#pragma mark -
#pragma mark update postion

- (void) setLocationToLatitude: (NSString *) lat longitude: (NSString *) lng
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if (lat && lng) {
	[self setLatitude: [lat doubleValue]];
	[self setLongitude: [lng doubleValue]];
    } else {
	[self setLatitude: 0.0];
    	[self setLongitude: 0.0];
    }
}

#pragma mark -
#pragma mark update files

- (void) backupFile
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *dest = [[NSHomeDirectory()
		       stringByAppendingPathComponent: @".Trash"]
		      stringByAppendingPathComponent: [self name]];
    if (! [fileManager fileExistsAtPath: dest])
	[fileManager copyPath: [self path]
		       toPath: dest
		      handler: nil];
}
- (void) saveLocation
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if (([self latitude] != [self originalLatitude]) ||
	([self longitude] != [self originalLongitude])) {

	if ([GTDefaultsController makeBackupFiles])
	    [self backupFile];

	NSMutableString *latArg =
	    [NSMutableString stringWithString: @"-GPSLatitude="];
	NSMutableString *latRefArg =
	    [NSMutableString stringWithString: @"-GPSLatitudeRef="];
	if ([self latitude]) {
	    CGFloat lat = [self latitude];
	    if (lat < 0) {
		[latRefArg appendString: @"S"];
		lat = -lat;
	    } else
		[latRefArg appendString: @"N"];
	    [latArg appendFormat: @"%f", lat];
	}

	NSMutableString *lngArg =
	    [NSMutableString stringWithString: @"-GPSLongitude="];
	NSMutableString *lngRefArg =
	    [NSMutableString stringWithString: @"-GPSLongitudeRef="];
	if ([self longitude]) {
	    CGFloat lng = [self longitude];
	    if (lng < 0) {
		[lngRefArg appendString: @"W"];
		lng = -lng;
	    } else
		[lngRefArg appendString: @"E"];
	    [lngArg appendFormat: @"%f", lng];
	}

	NSTask *exiftool = [[NSTask alloc] init];
	[exiftool setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
	[exiftool setStandardError: [NSFileHandle fileHandleWithNullDevice]];
	[exiftool setLaunchPath:[GTDefaultsController exiftoolPath]];
	[exiftool setArguments:[NSArray arrayWithObjects: @"-q", @"-m",
				@"-overwrite_original", @"-gpsmapdatum=WGS-84",
				latArg, latRefArg, lngArg, lngRefArg,
				[self path], nil]];
	[exiftool launch];
	[exiftool waitUntilExit];
	;;; // check for error?
	[self setOriginalLatitude: [self latitude]];
	[self setOriginalLongitude: [self longitude]];
    }
}

- (void) revertLocation
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if ([self originalLatitude] && [self originalLongitude]) {
	[self setLatitude: [self originalLatitude]];
	[self setLongitude: [self originalLongitude]];
    } else {
	[self setLatitude: 0.0];
	[self setLongitude: 0.0];
    }
}

#pragma mark -
#pragma mark helper functions

- (BOOL) getInfoForFileAt: (NSString *) path
{
    NSURL *url = [NSURL fileURLWithPath: path];
    CGImageSourceRef image = CGImageSourceCreateWithURL((CFURLRef) url, NULL);
    if (! image)
	return NO;
    NSDictionary *metadata = 
	(NSDictionary *) CGImageSourceCopyPropertiesAtIndex(image, 0, NULL);
    CFRelease(image);

    // orientation
    NSNumber *rotate =
	[metadata objectForKey: (NSString *) kCGImagePropertyOrientation];
    switch ([rotate integerValue]) {
	case 1:
	    [self setOrientation: 0.0];
	    break;
	case 8:
	    [self setOrientation: 90.0];
	    break;
	case 3:
	    [self setOrientation: 180.0];
	    break;
	case 6:
	    [self setOrientation: -90.0];
	    break;
    }

    // image creation date/time
    NSDictionary *exifdata = (NSDictionary *)
	[metadata objectForKey: (NSString *) kCGImagePropertyExifDictionary];
    NSString *dateTime =
	[exifdata objectForKey: (NSString *) kCGImagePropertyExifDateTimeOriginal];
    if (dateTime)
	[infoDict setObject: [NSString stringWithString: dateTime]
		     forKey: IIDateTime];

    // latitude and longitude
    NSDictionary *gpsdata = (NSDictionary *)
	[metadata objectForKey: (NSString *) kCGImagePropertyGPSDictionary];
    NSString *lat =
	[gpsdata objectForKey: (NSString *) kCGImagePropertyGPSLatitude];
    if (lat) {
	NSString *latRef=
	    [gpsdata objectForKey: (NSString *) kCGImagePropertyGPSLatitudeRef];
	if (latRef && [latRef isEqualToString: @"N"])
	    [self setLatitude: [lat doubleValue]];
	else
	    [self setLatitude: -[lat doubleValue]];
    }
    
    NSString *lng =
	[gpsdata objectForKey: (NSString *) kCGImagePropertyGPSLongitude];
    if (lng) {
	NSString *lngRef=
	    [gpsdata objectForKey: (NSString *) kCGImagePropertyGPSLongitudeRef];
	if (lngRef && [lngRef isEqualToString: @"E"])
	    [self setLongitude: [lng doubleValue]];
	else
	    [self setLongitude: -[lng doubleValue]];
    }
    return YES;
}

@end
