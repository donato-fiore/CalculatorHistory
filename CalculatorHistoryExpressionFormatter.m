#import "CalculatorHistoryExpressionFormatter.h"
#import "Utils.h"
#import "Localize.h"

@implementation CalculatorHistoryExpressionFormatter {
    NSDateFormatter *_dateFormatter;
    NSDateFormatter *_timeFormatter;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.locale = [NSLocale autoupdatingCurrentLocale];
        _dateFormatter.calendar = [NSCalendar autoupdatingCurrentCalendar];
        _dateFormatter.doesRelativeDateFormatting = YES;
        _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        _dateFormatter.timeStyle = NSDateFormatterNoStyle;

        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.locale = [NSLocale autoupdatingCurrentLocale];
        _timeFormatter.calendar = [NSCalendar autoupdatingCurrentCalendar];
        _timeFormatter.dateStyle = NSDateFormatterNoStyle;
        _timeFormatter.timeStyle = NSDateFormatterShortStyle;
    }

    return self;
}

+ (instancetype)sharedFormatter {
    static CalculatorHistoryExpressionFormatter *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSArray *)relativeDateComponentsFromDate:(NSDate *)date {
    NSString *relativeDate = [_dateFormatter stringFromDate:date];
    NSString *formattedTime = [_timeFormatter stringFromDate:date];

    return @[relativeDate, formattedTime];
}

- (NSAttributedString *)formatEquation:(NSString *)equation {
    return [self formatEquation:equation font:nil color:nil expressionOnly:NO];
}

- (NSAttributedString *)formatEquation:(NSString *)equation
                                  font:(UIFont *)font
                                 color:(UIColor *)color
                        expressionOnly:(BOOL)expressionOnly {
    if (equation.length == 0) return [[NSAttributedString alloc] initWithString:@""];

    UIFont *baseFont = font ?: [UIFont systemFontOfSize:20.0];
    UIColor *fullColor = color;

    CGFloat scriptScale = 0.6;
    CGFloat scriptOffsetScale = 0.5;

    UIFont *scriptFont = [UIFont fontWithDescriptor:baseFont.fontDescriptor
                                               size:baseFont.pointSize * scriptScale];

    NSNumber *superscriptOffset = @(baseFont.pointSize * scriptOffsetScale);
    NSNumber *subscriptOffset = @(-(baseFont.pointSize * scriptOffsetScale));

    // Convert E notation: 1.23E5 -> 1.23×10>>5>>
    NSString *regexPattern = @"E([+-]?\\d+)";
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:regexPattern
                                                                      options:0
                                                                        error:nil];

    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:equation
                                                              options:0
                                                                range:NSMakeRange(0, equation.length)];

    for (NSInteger i = matches.count - 1; i >= 0; i--) {
        NSTextCheckingResult *match = matches[i];
        NSRange fullRange = [match rangeAtIndex:0];
        NSRange exponentRange = [match rangeAtIndex:1];
        NSString *exponent = [equation substringWithRange:exponentRange];
        NSString *replacement = [NSString stringWithFormat:@"×10>>%@>>", exponent];
        equation = [equation stringByReplacingCharactersInRange:fullRange withString:replacement];
    }

    if (expressionOnly) {
        NSRange equalsRange = [equation rangeOfString:@"=" options:NSBackwardsSearch];
        if (equalsRange.location != NSNotFound) {
            equation = [equation substringToIndex:equalsRange.location];
        }
    }

    NSMutableDictionary *baseAttributes = [NSMutableDictionary dictionaryWithDictionary:@{
        NSFontAttributeName: baseFont
    }];

    if (fullColor) {
        baseAttributes[NSForegroundColorAttributeName] = fullColor;
    }

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:equation
                                                                                         attributes:baseAttributes];

    if (!expressionOnly && !fullColor) {
        NSRange currentEqualsRange = [equation rangeOfString:@"=" options:NSBackwardsSearch];
        if (currentEqualsRange.location != NSNotFound) {
            NSRange lhsRange = NSMakeRange(0, NSMaxRange(currentEqualsRange));
            [attributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor systemOrangeColor]
                                     range:lhsRange];
        }
    }

    // Superscript: >>text>>
    NSRegularExpression *superscriptRegex = [NSRegularExpression regularExpressionWithPattern:@">>(.*?)>>"
                                                                                      options:0
                                                                                        error:nil];

    NSArray<NSTextCheckingResult *> *superscriptMatches = [superscriptRegex matchesInString:attributedString.string
                                                                                    options:0
                                                                                      range:NSMakeRange(0, attributedString.string.length)];

    for (NSTextCheckingResult *match in superscriptMatches) {
        NSRange contentRange = [match rangeAtIndex:1];
        [attributedString addAttributes:@{
            NSFontAttributeName: scriptFont,
            NSBaselineOffsetAttributeName: superscriptOffset
        } range:contentRange];
    }

    // Subscript: <<text
    NSRegularExpression *subscriptRegex = [NSRegularExpression regularExpressionWithPattern:@"<<(.*?)<<"
                                                                                    options:0
                                                                                      error:nil];

    NSArray<NSTextCheckingResult *> *subscriptMatches = [subscriptRegex matchesInString:attributedString.string
                                                                                options:0
                                                                                  range:NSMakeRange(0, attributedString.string.length)];

    for (NSTextCheckingResult *match in subscriptMatches) {
        NSRange contentRange = [match rangeAtIndex:1];
        [attributedString addAttributes:@{
            NSFontAttributeName: scriptFont,
            NSBaselineOffsetAttributeName: subscriptOffset
        } range:contentRange];
    }

    [attributedString.mutableString replaceOccurrencesOfString:@"<<"
                                                    withString:@""
                                                       options:0
                                                         range:NSMakeRange(0, attributedString.mutableString.length)];

    [attributedString.mutableString replaceOccurrencesOfString:@">>"
                                                    withString:@""
                                                       options:0
                                                         range:NSMakeRange(0, attributedString.mutableString.length)];

    return attributedString;
}

- (NSString *)parseExpression:(NSString *)expression {
    NSLog(@"parsing expression: %@", expression);

    if ([expression isEqualToString:@"pi"] || [expression isEqualToString:@"exp(1)"]) return @"";
    expression = [expression stringByReplacingOccurrencesOfString:@"3.141592653589793238462643383279503" withString:@"π"];
    expression = [expression stringByReplacingOccurrencesOfString:@"2.718281828459045235360287471352662" withString:@"e"];

    if (specialBehavior == SpecialBehavior_radical && (![expression containsString:@"pow"] || ![expression containsString:@"/"])) {
        NSLog(@"invalidating specialB");
        specialBehavior = SpecialBehavior_none;
    }
    if ([expression containsString:@"pow("] && [expression containsString:@")*("]) specialBehavior = SpecialBehavior_scientificNotation;
    if (specialBehavior == SpecialBehavior_logarithm && ![expression containsString:@"log("]) specialBehavior = SpecialBehavior_none;
    if ([expression containsString:@"log("]) specialBehavior = SpecialBehavior_logarithm;

    if ([expression containsString:@"pow("] && [expression containsString:@"1.0/"]) {
        NSLog(@"power with inverse");
        NSArray *components = [expression componentsSeparatedByString:@",(1.0/"];
        NSString *radicand = [components.firstObject componentsSeparatedByString:@"pow("].lastObject;
        NSString *index = [components.lastObject stringByReplacingOccurrencesOfString:@"))" withString:@""];

        NSLog(@"components: %@", components);
        NSLog(@"radicand: %@", radicand);
        NSLog(@"index: %@", index);
        NSString *fom = [NSString stringWithFormat:@"%@√(%@)", superscript(index), radicand];
        NSLog(@"formatted: %@", fom);
        return fom;
    }

    switch (specialBehavior) {
        case SpecialBehavior_percent:
            specialBehavior = SpecialBehavior_none;
            expression = [expression componentsSeparatedByString:@"/"].firstObject;
            expression = [expression stringByReplacingOccurrencesOfString:@"(" withString:@""];
            expression = [expression stringByReplacingOccurrencesOfString:@")" withString:@""];
            expression = [NSString stringWithFormat:@"%@％", expression];
            if ([expression isEqualToString:@"0％"]) return @"";
            return expression;
        case SpecialBehavior_radical: {
                NSLog(@"using radical");
                specialBehavior = SpecialBehavior_none;
                NSArray *components = [expression componentsSeparatedByString:@","];
                NSString *radicand = [components.firstObject componentsSeparatedByString:@"("].lastObject;
                if ([radicand isEqualToString:@"0"]) return @"";
                NSString *index = [components.lastObject componentsSeparatedByString:@"/"].lastObject;
                index = [index stringByReplacingOccurrencesOfString:@")" withString:@""];
                if ([index isEqualToString:@"2"]) return [NSString stringWithFormat:@"√(%@)", radicand];
                if ([index isEqualToString:@"3"]) return [NSString stringWithFormat:@"∛(%@)", radicand];

                NSLog(@"%@ sqrt(%@)", index, radicand);

                return [NSString stringWithFormat:@"%@√(%@)", superscript(index), radicand];
        }
        case SpecialBehavior_reciprocal:
            expression = [[expression componentsSeparatedByString:@"("].lastObject stringByReplacingOccurrencesOfString:@")" withString:@""];
            return [NSString stringWithFormat:@"%@>>-1>>", expression];
        case SpecialBehavior_scientificNotation: {
            specialBehavior = SpecialBehavior_none;
            NSArray *components = [expression componentsSeparatedByString:@")*("];

            NSString *coefficient = [components.lastObject stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSString *exponent = [components.firstObject componentsSeparatedByString:@","].lastObject;
            return [NSString stringWithFormat:@"%@×10%@", coefficient, superscript(exponent)];
        }
        case SpecialBehavior_logarithm: {
            specialBehavior = SpecialBehavior_none;
            NSArray *components = [expression componentsSeparatedByString:@"log("];
            NSString *base = [components.lastObject stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSString *argument = [[components[1] componentsSeparatedByString:@"("].lastObject stringByReplacingOccurrencesOfString:@")/" withString:@""];
            return [NSString stringWithFormat:@"log%@(%@)", subscript(base), argument];
        }
    }

    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdfghijklmnopqrstuvwxyz"];
    bool basicExpression = ([expression.lowercaseString rangeOfCharacterFromSet:validChars].location == NSNotFound);

    if (basicExpression) {
        expression = [expression stringByReplacingOccurrencesOfString:@"(" withString:@" "];
        expression = [expression stringByReplacingOccurrencesOfString:@")" withString:@" "];
        expression = [expression stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        expression = [expression stringByReplacingOccurrencesOfString:@"*" withString:@"×"];
        expression = [expression stringByReplacingOccurrencesOfString:@"/" withString:@"÷"];
    } else {
        NSArray *components = [expression componentsSeparatedByString:@"("];
        if ([components.firstObject isEqualToString:@"exp"]) {
            expression = [NSString stringWithFormat:@"e%@", superscript([components.lastObject componentsSeparatedByString:@")"].firstObject)];
        } else if ([components.firstObject isEqualToString:@"pow"]) {
            NSString *base = [components.lastObject componentsSeparatedByString:@","].firstObject;
            NSString *exponent = [[[components.lastObject componentsSeparatedByString:@","].lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]stringByReplacingOccurrencesOfString:@")" withString:@""];

            expression = [NSString stringWithFormat:@"%@%@", base, superscript(exponent)];
        }

        for (NSString *trigFunction in @[@"sin", @"cos", @"tan"]) {
            if ([components.firstObject containsString:trigFunction]) {
                NSString *function = [components.firstObject stringByReplacingOccurrencesOfString:@"d" withString:@""];
                if ([components.firstObject hasPrefix:@"a"]) {
                    function = [function substringFromIndex:[@"a" length]];
                    function = [NSString stringWithFormat:@"%@⁻¹", function];
                }
                expression = [NSString stringWithFormat:@"%@(%@", function, components.lastObject];
            }
        }
    }

    NSLog(@"final expression: %@", expression);

    return expression;
}

@end
