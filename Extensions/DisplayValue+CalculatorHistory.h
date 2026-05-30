#import "../Tweak.h"

@interface DisplayValue (CalculatorConverter)

- (instancetype)initWithValue:(NSString *)value userEntered:(BOOL)userEntered;
- (NSString *)valueString;
- (BOOL)isUserEntered;

@end