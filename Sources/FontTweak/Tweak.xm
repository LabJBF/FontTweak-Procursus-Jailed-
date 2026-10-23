#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#define FONTTWEAK_HAS_ROOTLESS_H 1
#endif

static NSString * const kFontsDirLogicalPath = @"/Library/Application Support/FontTweak/Fonts";
static NSString * const kPrefsSuite = @"org.emexlabs.fonttweak";
static NSString * const kRegularFileKey = @"RegularFontFile"; // e.g. "SomeFont-Regular.ttf"
static NSString * const kBoldFileKey = @"BoldFontFile";       // optional

// fileName -> registered PostScript name, built once at process start by
// scanning the Fonts folder. New files added later need a respring to
// show up in this map (TweakSettings' picker lists files on disk
// directly, so it doesn't need this - only the hook's registration
// does).
static NSMutableDictionary<NSString *, NSString *> *gFontNamesByFile = nil;

static NSString * FontTweakFontsDirPath(void) {
#ifdef FONTTWEAK_HAS_ROOTLESS_H
	return jbroot(kFontsDirLogicalPath);
#else
	return kFontsDirLogicalPath;
#endif
}

static NSString * FontTweakRegisterFontFile(NSString *path) {
	NSURL *url = [NSURL fileURLWithPath:path];

	CFErrorRef error = NULL;
	if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error)) {
		if (error) CFRelease(error); // may just mean "already registered"
	}

	CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
	if (!descriptors || CFArrayGetCount(descriptors) == 0) {
		if (descriptors) CFRelease(descriptors);
		return nil;
	}

	CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0);
	CFStringRef psName = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
	NSString *name = psName ? [(__bridge NSString *)psName copy] : nil;
	if (psName) CFRelease(psName);
	CFRelease(descriptors);

	return name;
}

static void FontTweakScanAndRegisterAll(void) {
	gFontNamesByFile = [NSMutableDictionary dictionary];

	NSString *dir = FontTweakFontsDirPath();
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:nil];

	for (NSString *file in files) {
		NSString *ext = file.pathExtension.lowercaseString;
		if (![ext isEqualToString:@"ttf"] && ![ext isEqualToString:@"otf"]) continue;

		NSString *full = [dir stringByAppendingPathComponent:file];
		NSString *psName = FontTweakRegisterFontFile(full);
		if (psName) {
			gFontNamesByFile[file] = psName;
		}
	}

	NSLog(@"[FontTweak] registered fonts: %@", gFontNamesByFile);
}

// Reads the current selection fresh each call (cheap NSUserDefaults
// read) so switching fonts in TweakSettings takes effect for any UI
// built *after* the change, without needing to re-register anything.
static UIFont * FontTweakFontForSizeAndWeight(CGFloat size, UIFontWeight weight) {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
	BOOL wantsBold = weight >= UIFontWeightSemibold;

	NSString *file = wantsBold ? [defaults stringForKey:kBoldFileKey] : nil;
	if (!file) file = [defaults stringForKey:kRegularFileKey];
	if (!file) return nil;

	NSString *psName = gFontNamesByFile[file];
	if (!psName) return nil;

	return [UIFont fontWithName:psName size:size];
}

%hook UIFont

+ (UIFont *)systemFontOfSize:(CGFloat)size {
	UIFont *custom = FontTweakFontForSizeAndWeight(size, UIFontWeightRegular);
	return custom ?: %orig;
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
	UIFont *custom = FontTweakFontForSizeAndWeight(size, UIFontWeightBold);
	return custom ?: %orig;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
	UIFont *custom = FontTweakFontForSizeAndWeight(size, weight);
	return custom ?: %orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
	UIFont *orig = %orig;
	UIFont *custom = FontTweakFontForSizeAndWeight(orig.pointSize, UIFontWeightRegular);
	return custom ?: orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
	UIFont *orig = %orig;
	UIFont *custom = FontTweakFontForSizeAndWeight(orig.pointSize, UIFontWeightRegular);
	return custom ?: orig;
}

%end

%ctor {
	// Make sure the Fonts folder exists so TweakSettings/Filza/the Files
	// app has somewhere obvious to drop files into on first install.
	NSString *dir = FontTweakFontsDirPath();
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

	FontTweakScanAndRegisterAll();
}
