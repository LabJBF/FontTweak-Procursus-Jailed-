#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#define FONTTWEAK_HAS_ROOTLESS_H 1
#endif

static NSString * const kFontsDirLogicalPath = @"/Library/Application Support/FontTweak/Fonts";
static NSString * const kPrefsSuite = @"org.emexlabs.fonttweak";
static NSString * const kEnabledKey = @"Enabled"; // matches the PSSwitchCell in FontTweak.plist

static NSString *gCustomFontName = nil; // PostScript name of whatever we found, or nil

static NSString * FontTweakFontsDirPath(void) {
#ifdef FONTTWEAK_HAS_ROOTLESS_H
	return jbroot(kFontsDirLogicalPath);
#else
	return kFontsDirLogicalPath;
#endif
}

// Registers the first .ttf/.otf found in the Fonts folder and returns
// its real PostScript name. Deliberately simple: one font, no
// regular/bold distinction yet, to keep this version as low-risk as
// possible. Drop exactly one font file in the folder for now.
static NSString * FontTweakRegisterFirstFont(void) {
	NSString *dir = FontTweakFontsDirPath();
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

	NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[];
	for (NSString *file in [files sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
		NSString *ext = file.pathExtension.lowercaseString;
		if (![ext isEqualToString:@"ttf"] && ![ext isEqualToString:@"otf"]) continue;

		NSString *full = [dir stringByAppendingPathComponent:file];
		NSURL *url = [NSURL fileURLWithPath:full];

		CFErrorRef error = NULL;
		if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error)) {
			if (error) CFRelease(error); // may just mean already registered
		}

		CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
		if (!descriptors || CFArrayGetCount(descriptors) == 0) {
			if (descriptors) CFRelease(descriptors);
			continue;
		}

		CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, 0);
		CFStringRef psName = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
		NSString *name = psName ? [(__bridge NSString *)psName copy] : nil;
		if (psName) CFRelease(psName);
		CFRelease(descriptors);

		if (name) {
			NSLog(@"[FontTweak] registered %@ as %@", file, name);
			return name;
		}
	}

	NSLog(@"[FontTweak] no .ttf/.otf found in %@", dir);
	return nil;
}

static BOOL FontTweakIsEnabled(void) {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
	return [defaults boolForKey:kEnabledKey];
}

static UIFont * FontTweakFontForSize(CGFloat size) {
	if (!gCustomFontName) return nil;
	if (!FontTweakIsEnabled()) return nil;
	return [UIFont fontWithName:gCustomFontName size:size];
}

%hook UIFont

+ (UIFont *)systemFontOfSize:(CGFloat)size {
	UIFont *custom = FontTweakFontForSize(size);
	return custom ?: %orig;
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
	UIFont *custom = FontTweakFontForSize(size);
	return custom ?: %orig;
}

+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
	UIFont *custom = FontTweakFontForSize(size);
	return custom ?: %orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
	UIFont *orig = %orig;
	UIFont *custom = FontTweakFontForSize(orig.pointSize);
	return custom ?: orig;
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
	UIFont *orig = %orig;
	UIFont *custom = FontTweakFontForSize(orig.pointSize);
	return custom ?: orig;
}

%end

%ctor {
	gCustomFontName = FontTweakRegisterFirstFont();
}
