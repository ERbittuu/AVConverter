#import "ScreenCaptureView.h"

@implementation ScreenCaptureView

- (void) initialize {
	// initialization code
	self.clearsContextBeforeDrawing = YES;
	bitmapData = NULL;
    index = 0;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initialize];
	}
	return self;
}

- (id) init {
	self = [super init];
	if (self) {
		[self initialize];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self initialize];
	}
	return self;
}

- (CGContextRef) createBitmapContextOfSize:(CGSize) size {
	CGContextRef    context = NULL;
	CGColorSpaceRef colorSpace;
	int             bitmapByteCount;
	int             bitmapBytesPerRow;
	
	bitmapBytesPerRow   = (size.width * 4);
	bitmapByteCount     = (bitmapBytesPerRow * size.height);
	colorSpace = CGColorSpaceCreateDeviceRGB();
	if (bitmapData != NULL) {
		free(bitmapData);
	}
	bitmapData = malloc( bitmapByteCount );
	if (bitmapData == NULL) {
		fprintf (stderr, "Memory not allocated!");
		return NULL;
	}
	
	context = CGBitmapContextCreate (bitmapData,
									 size.width,
									 size.height,
									 8,      // bits per component
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaNoneSkipFirst);
	
	CGContextSetAllowsAntialiasing(context,NO);
	if (context== NULL) {
		free (bitmapData);
		fprintf (stderr, "Context not created!");
		return NULL;
	}
	CGColorSpaceRelease( colorSpace );
	return context;
}

- (void) drawRect:(CGRect)rect {
	CGContextRef context = [self createBitmapContextOfSize:self.frame.size];
	
	//not sure why this is necessary...image renders upside-down and mirrored
	CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, self.frame.size.height);
	CGContextConcatCTM(context, flipVertical);
	
	[self.layer renderInContext:context];
	
	CGImageRef cgImage = CGBitmapContextCreateImage(context);
	UIImage* background = [UIImage imageWithCGImage: cgImage];
	CGImageRelease(cgImage);
	
    NSString* filename = [NSString stringWithFormat:@"/frame_%d.png", index];
    NSString* pngPath = [self.imageName stringByAppendingPathComponent:filename];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        [UIImagePNGRepresentation(background) writeToFile: pngPath atomically: YES];
    });
    index++;
	CGContextRelease(context);
    [super drawRect:rect];
}

- (void)dealloc {
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
	[super dealloc];
}

@end
