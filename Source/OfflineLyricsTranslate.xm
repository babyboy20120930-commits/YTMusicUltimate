#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface LocalLyricsTranslator : NSObject
+ (void)translate:(NSString *)text completion:(void (^)(NSString * _Nullable result))completion;
@end

// 1. Intercept the translation button tap to block server verification and the premium upsell popup
%hook YTMLyricsViewController

- (void)didTapTranslateButton:(id)sender {
    // Block the original paid verification popup and trigger local update safely
    if ([self respondsToSelector:@selector(reloadData)]) {
        ((void (*)(id, SEL))[self methodForSelector:@selector(reloadData)])(self, @selector(reloadData));
    }
}

%end

// 2. Overlay the Chinese translation below the English text when the lyrics cell renders
%hook YTMLyricsLineCell

- (void)layoutSubviews {
    %orig;
    
    // Safely extract the lyric label using KVC without forward declaration issues
    id labelObj = [self valueForKey:@"lyricLabel"];
    if (!labelObj || ![labelObj isKindOfClass:[UILabel class]]) return;
    
    UILabel *label = (UILabel *)labelObj;
    if (label.text.length == 0) return;
    
    // Store original English text to prevent duplicate triggers
    NSString *originalText = objc_getAssociatedObject(label, "originalLyricText");
    if (!originalText) {
        originalText = label.text;
        objc_setAssociatedObject(label, "originalLyricText", originalText, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    
    if (@available(iOS 17.4, *)) {
        [LocalLyricsTranslator translate:originalText completion:^(NSString *result) {
            if (result.length > 0 && ![label.text containsString:result]) {
                NSString *combined = [NSString stringWithFormat:@"%@\n%@", originalText, result];
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:combined];
                
                // Set styling for the upper English original text
                [attrStr addAttributes:@{
                    NSFontAttributeName: label.font ?: [UIFont boldSystemFontOfSize:17],
                    NSForegroundColorAttributeName: label.textColor ?: [UIColor whiteColor]
                } range:NSMakeRange(0, originalText.length)];
                
                // Set styling for the lower Chinese translation text (smaller size, semi-transparent)
                [attrStr addAttributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:14],
                    NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.65]
                } range:NSMakeRange(originalText.length + 1, result.length)];
                
                label.numberOfLines = 0;
                label.attributedText = attrStr;
                
                if ([self respondsToSelector:@selector(setNeedsLayout)]) {
                    ((void (*)(id, SEL))[self methodForSelector:@selector(setNeedsLayout)])(self, @selector(setNeedsLayout));
                }
            }
        }];
    }
}

%end
