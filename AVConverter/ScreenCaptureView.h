#import <UIKit/UIKit.h>

@interface ScreenCaptureView : UIView {
	void* bitmapData;
    int index;
    
}
@property (nonatomic, strong)NSString *imageName;
@end
