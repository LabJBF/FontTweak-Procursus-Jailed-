// Preferences.framework ships no public headers - these forward
// declarations are the standard approach every Settings-bundle-style
// preference pane tweak uses (PSListController/PSSpecifier are real
// classes on-device, just undocumented). NOT verified against
// TweakSettings specifically - see README for what to check.

#import <UIKit/UIKit.h>

@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                   target:(id)target
                                      set:(SEL)set
                                      get:(SEL)get
                                   detail:(Class)detail
                                     cell:(int)cell
                                     edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
@property (nonatomic) SEL buttonAction;
@end

@interface PSListController : UITableViewController
@property (nonatomic, retain) PSSpecifier *specifier;
@property (nonatomic, retain) NSMutableArray *_specifiers;
- (void)reloadSpecifiers;
@end

@interface FontTweakListController : PSListController
@end
