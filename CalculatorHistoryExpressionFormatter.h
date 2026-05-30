#import "Tweak.h"

@interface CalculatorHistoryExpressionFormatter : NSObject

+ (instancetype)sharedFormatter;

- (NSArray *)relativeDateComponentsFromDate:(NSDate *)date;

- (NSString *)parseExpression:(NSString *)expression;

- (NSAttributedString *)formatEquation:(NSString *)equation
                                  font:(UIFont *)font
                                 color:(UIColor *)color
                        expressionOnly:(BOOL)expressionOnly;

- (NSAttributedString *)formatEquation:(NSString *)equation;

@end