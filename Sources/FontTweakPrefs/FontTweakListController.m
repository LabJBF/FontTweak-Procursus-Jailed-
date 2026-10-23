#import "FontTweakListController.h"

#if __has_include(<rootless.h>)
#import <rootless.h>
#define FONTTWEAKPREFS_HAS_ROOTLESS_H 1
#endif

static NSString * const kPrefsSuite = @"org.emexlabs.fonttweak";
static CFStringRef const kChangedNotification = CFSTR("org.emexlabs.fonttweak/FontsChanged");

@implementation FontTweakListController

- (NSString *)role {
	// Root.plist sets this per-row via the "role" property so one
	// controller class serves both "Regular Font" and "Bold Font".
	id role = [self.specifier propertyForKey:@"role"];
	return [role isKindOfClass:[NSString class]] ? role : @"Regular";
}

- (NSString *)prefsKey {
	return [self.role isEqualToString:@"Bold"] ? @"BoldFontFile" : @"RegularFontFile";
}

- (NSString *)fontsDirectory {
	NSString *logical = @"/Library/Application Support/FontTweak/Fonts";
#ifdef FONTTWEAKPREFS_HAS_ROOTLESS_H
	return jbroot(logical);
#else
	return logical;
#endif
}

- (NSMutableArray *)specifiers {
	// Rebuilt every time rather than cached in __specifiers, so newly
	// dropped-in font files show up without needing to leave and
	// re-enter this screen.
	NSMutableArray *specs = [NSMutableArray array];

	PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@""
	                                                      target:self
	                                                         set:NULL
	                                                         get:NULL
	                                                      detail:Nil
	                                                        cell:0 /* PSGroupCell - verify constant */
	                                                        edit:Nil];
	[group setProperty:[NSString stringWithFormat:@"%@ Font", self.role] forKey:@"label"];
	[specs addObject:group];

	NSString *dir = [self fontsDirectory];
	NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
	NSString *currentFile = [[[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite] stringForKey:[self prefsKey]];

	for (NSString *file in [files sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
		NSString *ext = file.pathExtension.lowercaseString;
		if (![ext isEqualToString:@"ttf"] && ![ext isEqualToString:@"otf"]) continue;

		PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:file
		                                                    target:self
		                                                       set:NULL
		                                                       get:NULL
		                                                    detail:Nil
		                                                      cell:11 /* PSButtonCell - verify constant */
		                                                      edit:Nil];
		[row setProperty:file forKey:@"fileName"];
		[row setProperty:@([file isEqualToString:currentFile]) forKey:@"isSelected"];
		row.buttonAction = @selector(selectFont:);
		[specs addObject:row];
	}

	if (files.count == 0) {
		PSSpecifier *empty = [PSSpecifier preferenceSpecifierNamed:@"No fonts found"
		                                                      target:self
		                                                         set:NULL
		                                                         get:NULL
		                                                      detail:Nil
		                                                        cell:3 /* PSStaticTextCell - verify constant */
		                                                        edit:Nil];
		[specs addObject:empty];
	}

	return specs;
}

- (void)selectFont:(PSSpecifier *)specifier {
	NSString *file = [specifier propertyForKey:@"fileName"];
	if (!file) return;

	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
	[defaults setObject:file forKey:[self prefsKey]];
	[defaults synchronize];

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
	                                      kChangedNotification,
	                                      NULL, NULL, true);

	[self reloadSpecifiers];
}

@end
