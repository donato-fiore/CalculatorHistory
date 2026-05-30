#import "Tweak.h"

#ifdef __cplusplus
extern "C" {
#endif

static NSString * const CalcHistoryAttributedSubtitlePrefix = @"ATTR://";

extern NSInteger specialBehavior;
extern bool bypassDefault;

NSRange rangeOfNthOccurrence(NSString *string, NSString *substring, NSInteger occurrence);

NS_INLINE NSString *superscript(NSString *string) {
    return [NSString stringWithFormat:@">>%@>>", string];
}

NS_INLINE NSString *subscript(NSString *string) {
    return [NSString stringWithFormat:@"<<%@<<", string];
}

#ifdef __cplusplus
}
#endif