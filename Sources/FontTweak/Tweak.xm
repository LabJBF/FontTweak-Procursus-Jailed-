
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <roothide.h>

static NSString * const kFontsDirLogicalPath = @"/Library/Application Support/FontTweak/Fonts";
static NSString * const kPrefsSuite = @"org.emexlabs.fonttweak";
static NSString * const kRegularFileKey = @"RegularFontFile";
static NSString * const kBoldFileKey = @"BoldFontFile";

// Maps font filenames to their registered PostScript names.
static NSMutableDictionary<NSString *, NSString *> *gFontNamesByFile = nil;

// Resolve the logical path using RootHide.
static NSString *FontTweakFontsDirPath(void) {
    return jbroot(kFontsDirLogicalPath);
}

static NSString *FontTweakRegisterFontFile(NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];

    CFErrorRef error = NULL;
    if (!CTFontManagerRegisterFontsForURL(
            (__bridge CFURLRef)url,
            kCTFontManagerScopeProcess,
            &error)) {
        if (error) CFRelease(error);
    }

    CFArrayRef descriptors =
        CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);

    if (!descriptors || CFArrayGetCount(descriptors) == 0) {
        if (descriptors) CFRelease(descriptors);
        return nil;
    }

    CTFontDescriptorRef descriptor =
        (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0);

    CFStringRef psName = (CFStringRef)
        CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);

    NSString *name = psName ? [(__bridge NSString *)psName copy] : nil;

    if (psName) CFRelease(psName);
    CFRelease(descriptors);

    return name;
}

static void FontTweakScanAndRegisterAll(void) {
    gFontNamesByFile = [NSMutableDictionary dictionary];

    NSString *dir = FontTweakFontsDirPath();
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray<NSString *> *files =
        [fm contentsOfDirectoryAtPath:dir error:nil];

    for (NSString *file in files) {
        NSString *ext = file.pathExtension.lowercaseString;

        if (![ext isEqualToString:@"ttf"] &&
            ![ext isEqualToString:@"otf"]) {
            continue;
        }

        NSString *full = [dir stringByAppendingPathComponent:file];
        NSString *psName = FontTweakRegisterFontFile(full);

        if (psName) {
            gFontNamesByFile[file] = psName;
        }
    }

    NSLog(@"[FontTweak] Registered fonts: %@", gFontNamesByFile);
}

static UIFont *FontTweakFontForSizeAndWeight(
    CGFloat size,
    UIFontWeight weight
) {
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];

    BOOL wantsBold = weight >= UIFontWeightSemibold;

    NSString *file = wantsBold
        ? [defaults stringForKey:kBoldFileKey]
        : nil;

    if (!file) {
        file = [defaults stringForKey:kRegularFileKey];
    }

    if (!file) return nil;

    NSString *psName = gFontNamesByFile[file];
    if (!psName) return nil;

    return [UIFont fontWithName:psName size:size];
}

%hook UIFont

+ (UIFont *)systemFontOfSize:(CGFloat)size {
    UIFont *custom =
        FontTweakFontForSizeAndWeight(size, UIFontWeightRegular);

    return custom ?: %orig;
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
    UIFont *custom =
        FontTweakFontForSizeAndWeight(size, UIFontWeightBold);

    return custom ?: %orig;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *custom =
        FontTweakFontForSizeAndWeight(size, weight);

    return custom ?: %orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
    UIFont *original = %orig;

    UIFont *custom = FontTweakFontForSizeAndWeight(
        original.pointSize,
        UIFontWeightRegular
    );

    return custom ?: original;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style
         compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
    UIFont *original = %orig;

    UIFont *custom = FontTweakFontForSizeAndWeight(
        original.pointSize,
        UIFontWeightRegular
    );

    return custom ?: original;
}

%end

%ctor {
    NSString *dir = FontTweakFontsDirPath();

    [[NSFileManager defaultManager]
        createDirectoryAtPath:dir
        withIntermediateDirectories:YES
        attributes:nil
        error:nil];

    FontTweakScanAndRegisterAll();
}
Path:dir withIntermediateDirectories:YES attributes:nil error:nil];

	FontTweakScanAndRegisterAll();
}
