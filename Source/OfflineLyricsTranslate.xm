#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface LocalLyricsTranslator : NSObject
+ (void)translate:(NSString *)text completion:(void (^)(NSString * _Nullable result))completion;
@end

// Explicitly declare interfaces to prevent forward declaration compiler errors
@interface YTMLyricsViewController : UIViewController
- (void)reloadData;
@end

@interface YTMLyricsLineCell : UITableViewCell
@end

// 1. Intercept the translation button tap to block server verification and the premium upsell popup
%hook YTMLyricsViewController

- (void)didTapTranslateButton:(id)sender {
    // Block the original paid verification popup and trigger local update safely
    if ([self respondsToSelector:@selector(reloadData)]) {
        [self reloadData];
    }
}

%end

// 2. Overlay the Chinese translation below the English text when the lyrics cell renders
%hook YTMLyricsLineCell

- (void)layoutSubviews {
    %orig;
    
    // Safely extract the lyric label using KVC
    id labelObj = [self valueForKey:@"label"]; // 若畫面沒生效可改回 "lyricLabel"
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
                
                [self setNeedsLayout];
            }
        }];
    }
}

%end
