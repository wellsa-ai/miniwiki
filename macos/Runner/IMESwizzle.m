#import <FlutterMacOS/FlutterMacOS.h>
#import <objc/runtime.h>

// Swizzle FlutterTextInputPlugin to fix Korean IME composing issue.
// When composing (hasMarkedText), macOS sends deleteBackward: to decompose
// the last jamo. Flutter forwards this to Dart which causes selection.start - 1 = -1.
// Fix: skip forwarding deleteBackward: to Dart when composing is active.

static IMP original_doCommandBySelector = NULL;

static void swizzled_doCommandBySelector(id self, SEL _cmd, SEL selector) {
    // If composing (Korean jamo assembly) and deleteBackward:, let IME handle it
    if (selector == @selector(deleteBackward:) && [self hasMarkedText]) {
        // IME will update via setMarkedText: — don't send to Dart
        return;
    }

    // Call original implementation for all other cases
    if (original_doCommandBySelector) {
        ((void (*)(id, SEL, SEL))original_doCommandBySelector)(self, _cmd, selector);
    }
}

__attribute__((constructor))
static void installIMESwizzle(void) {
    // FlutterTextInputPlugin is a private class in FlutterMacOS framework
    Class cls = NSClassFromString(@"FlutterTextInputPlugin");
    if (!cls) return;

    SEL sel = @selector(doCommandBySelector:);
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    original_doCommandBySelector = method_setImplementation(method, (IMP)swizzled_doCommandBySelector);
}
