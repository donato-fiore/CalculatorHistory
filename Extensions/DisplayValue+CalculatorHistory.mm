#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

extern "C" void writeSwiftString(NSString *, void *);
extern "C" NSString *swiftStringToNSString(void *);

NSObject *bridgedInit(id self, SEL _cmd, NSString *value, BOOL userEntered) {
    struct objc_super superInfo = { self, [[self class] superclass] };
    id instance = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superInfo, @selector(init));
    if (!instance) return nil;

    Ivar valueIvar = class_getInstanceVariable([instance class], "value");
    if (!valueIvar) {
        NSLog(@"Error: Could not find 'value' ivar in class %@", [instance class]);
        return nil;
    }

    void *valuePtr = (char *)(__bridge void *)instance + ivar_getOffset(valueIvar);
    if (!valuePtr) {
        NSLog(@"Error: Value pointer is NULL for class %@", [instance class]);
        return nil;
    }

    writeSwiftString(value, valuePtr);
    MSHookIvar<BOOL>(instance, "userEntered") = userEntered;

    return instance;
}

NSString *getDisplayValue(id self, SEL _cmd) {
    Ivar valueIvar = class_getInstanceVariable([self class], "value");
    if (!valueIvar) {
        NSLog(@"Error: Could not find 'value' ivar in class %@", [self class]);
        return nil;
    }

    void *valuePtr = (char *)(__bridge void *)self + ivar_getOffset(valueIvar);
    if (!valuePtr) {
        NSLog(@"Error: Value pointer is NULL for class %@", [self class]);
        return nil;
    }

    NSString *value = swiftStringToNSString(valuePtr);
    if (!value) {
        NSLog(@"Error: Could not convert value pointer to NSString for class %@", [self class]);
        return nil;
    }

    return value;
}

BOOL getUserEntered(id self, SEL _cmd) {
    return MSHookIvar<BOOL>(self, "userEntered");
}

NSString *bridgedDescription(id self, SEL _cmd) {
    NSString *value = getDisplayValue(self, _cmd);
    BOOL userEntered = getUserEntered(self, _cmd);
    return [NSString stringWithFormat:@"<DisplayValue: value=%@, userEntered=%@>", value, userEntered ? @"YES" : @"NO"];
}

__attribute__((constructor)) static void init_DisplayValue_CalculatorConverter() {
    class_addMethod(objc_getClass("Calculator.DisplayValue"), sel_getUid("initWithValue:userEntered:"), (IMP)bridgedInit, "@@:@@B");
    class_addMethod(objc_getClass("Calculator.DisplayValue"), sel_getUid("valueString"), (IMP)getDisplayValue, "@@:");
    class_addMethod(objc_getClass("Calculator.DisplayValue"), sel_getUid("isUserEntered"), (IMP)getUserEntered, "B@:");
    class_addMethod(objc_getClass("Calculator.DisplayValue"), sel_getUid("description"), (IMP)bridgedDescription, "@@:");
}