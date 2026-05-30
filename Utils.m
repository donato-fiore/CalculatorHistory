#import "Utils.h"

NSRange rangeOfNthOccurrence(NSString *string, NSString *substring, NSInteger occurrence) {
    if (occurrence <= 0 || string.length == 0 || substring.length == 0) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSRange searchRange = NSMakeRange(0, string.length);
    NSRange foundRange = NSMakeRange(NSNotFound, 0);

    for (NSInteger i = 0; i < occurrence; i++) {
        NSRange range = [string rangeOfString:substring options:0 range:searchRange];
        if (range.location == NSNotFound) {
            return NSMakeRange(NSNotFound, 0);
        }
        foundRange = range;
        searchRange = NSMakeRange(NSMaxRange(range), string.length - NSMaxRange(range));
    }

    return foundRange;
}
