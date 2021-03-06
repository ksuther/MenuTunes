#import "PreferencesController.h"
#import "MainController.h"
#import "MenuController.h"
#import "NetworkController.h"
#import "NetworkObject.h"
#import "StatusWindow.h"
#import "StatusWindowController.h"
#import "CustomMenuTableView.h"
#import "AudioscrobblerController.h"

#import <Security/Security.h>

#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/types.h>
#import <sys/stat.h>

#import <ITKit/ITKit.h>
#import <ITKit/ITTSWBackgroundView.h>

#define SENDER_STATE (([sender state] == NSOnState) ? YES : NO)
#define AUDIOSCROBBLER_KEYCHAIN_SERVICE(user) [[NSString stringWithFormat:@"Audioscrobbler: %@", user] UTF8String]
#define AUDIOSCROBBLER_KEYCHAIN_KIND "application password"

/*************************************************************************/
#pragma mark -
#pragma mark PRIVATE INTERFACE
/*************************************************************************/

@interface PreferencesController (Private)
+ (SecKeychainItemRef)keychainItemForUser:(NSString *)user;
+ (BOOL)keychainItemExistsForUser:(NSString *)user;
+ (BOOL)createKeychainItemForUser:(NSString *)user andPassword:(NSString *)password;
+ (BOOL)deleteKeychainItemForUser:(NSString *)user;
+ (BOOL)setKeychainItemPassword:(NSString *)password forUser:(NSString *)user;

- (void)setupWindow;
- (void)setupCustomizationTables;
- (void)setupMenuItems;
- (void)setupUI;
- (void)setupScreenPopup;
- (void)setStatusWindowEntryEffect:(Class)effectClass;
- (void)setStatusWindowExitEffect:(Class)effectClass;
- (void)setCustomColor:(NSColor *)color updateWell:(BOOL)update;
- (void)repopulateEffectPopupsForVerticalPosition:(ITVerticalWindowPosition)vPos horizontalPosition:(ITHorizontalWindowPosition)hPos;
- (BOOL)effect:(Class)effectClass supportsVerticalPosition:(ITVerticalWindowPosition)vPos withHorizontalPosition:(ITHorizontalWindowPosition)hPos;
- (IBAction)changeMenus:(id)sender;
@end


@implementation PreferencesController


/*************************************************************************/
#pragma mark -
#pragma mark STATIC VARIABLES
/*************************************************************************/

static PreferencesController *prefs = nil;

/*************************************************************************/
#pragma mark -
#pragma mark STATIC KEYCHAIN SUPPORT METHODS
/*************************************************************************/

+ (SecKeychainItemRef)keychainItemForUser:(NSString *)user
{
	SecKeychainSearchRef search;
	SecKeychainItemRef item;
	OSStatus status;
	SecKeychainAttribute attributes[3];
	SecKeychainAttributeList list;

	if ((user == nil) || ([user length] == 0)) {
		return nil;
	}

	ITDebugLog(@"Audioscrobbler: Searching for keychain item for %@.", user);
	attributes[0].tag = kSecAccountItemAttr;
	attributes[0].data = (char *)[user UTF8String];
	attributes[0].length = [user length];
	attributes[1].tag = kSecDescriptionItemAttr;
	attributes[1].data = AUDIOSCROBBLER_KEYCHAIN_KIND;
	attributes[1].length = strlen(AUDIOSCROBBLER_KEYCHAIN_KIND);
	attributes[2].tag = kSecLabelItemAttr;
	attributes[2].data = (char *)AUDIOSCROBBLER_KEYCHAIN_SERVICE(user);
	attributes[2].length = strlen(AUDIOSCROBBLER_KEYCHAIN_SERVICE(user));
	list.count = 3;
	list.attr = attributes;

	status = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);

	if (status != noErr) {
		ITDebugLog(@"Audioscrobbler: Error searching for existing keychain item: %i", status);
	}
	
	status = SecKeychainSearchCopyNext(search, &item);
	
	if (status != noErr) {
		ITDebugLog(@"Audioscrobbler: Error searching for existing keychain item: %i", status);
		item = nil;
	}
	
    CFRelease(search);
	return item;
}

+ (BOOL)keychainItemExistsForUser:(NSString *)user
{
	SecKeychainItemRef item = [PreferencesController keychainItemForUser:user];
	BOOL exists = (item != nil);
	if (item) {
		CFRelease(item);
	}
	return exists;
}

+ (BOOL)createKeychainItemForUser:(NSString *)user andPassword:(NSString *)password
{
	SecKeychainItemRef item;
	OSStatus status;
	SecKeychainAttribute attributes[3];
	SecKeychainAttributeList list;

	ITDebugLog(@"Audioscrobbler: Creating new keychain item for %@.", user);
	attributes[0].tag = kSecAccountItemAttr;
	attributes[0].data = (char *)[user UTF8String];
	attributes[0].length = [user length];
	attributes[1].tag = kSecDescriptionItemAttr;
	attributes[1].data = AUDIOSCROBBLER_KEYCHAIN_KIND;
	attributes[1].length = strlen(AUDIOSCROBBLER_KEYCHAIN_KIND);
	attributes[2].tag = kSecLabelItemAttr;
	attributes[2].data = (char *)AUDIOSCROBBLER_KEYCHAIN_SERVICE(user);
	attributes[2].length = strlen(AUDIOSCROBBLER_KEYCHAIN_SERVICE(user));
	list.count = 3;
	list.attr = attributes;

	status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list, [password length], [password UTF8String], NULL, NULL, &item);
	if (status != noErr) {
		ITDebugLog(@"Audioscrobbler: Error creating keychain item: %i", status);
	}
	return (status == noErr);
}

+ (BOOL)deleteKeychainItemForUser:(NSString *)user
{
	OSStatus status = errSecNotAvailable;
	SecKeychainItemRef item = [PreferencesController keychainItemForUser:user];
	if (item != nil) {
		status = SecKeychainItemDelete(item);
		if (status != noErr) {
			ITDebugLog(@"Audioscrobbler: Error deleting keychain item: %i", status);
		}
		CFRelease(item);
	}
	return (status == noErr);
}

+ (BOOL)setKeychainItemPassword:(NSString *)password forUser:(NSString *)user
{
	OSStatus status = errSecNotAvailable;
	SecKeychainItemRef item = [PreferencesController keychainItemForUser:user];
	if (item != nil) {
		status = SecKeychainItemModifyContent(item, NULL, [password length], [password UTF8String]);
		if (status != noErr) {
			ITDebugLog(@"Audioscrobbler: Error deleting keychain item: %i", status);
		}
		CFRelease(item);
	}
	return (status == noErr);
}

+ (NSString *)getKeychainItemPasswordForUser:(NSString *)user
{
	OSStatus status = errSecNotAvailable;
	SecKeychainItemRef item = [PreferencesController keychainItemForUser:user];
	NSString *pass = nil;
	if (item != nil) {
		UInt32 length;
		char *buffer;
		status = SecKeychainItemCopyContent(item, NULL, NULL, &length, (void **)&buffer);
		if (status != noErr) {
			ITDebugLog(@"Audioscrobbler: Error getting keychain item password: %i", status);
		} else {
			pass = [[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
		}
		if (status != noErr) {
			ITDebugLog(@"Audioscrobbler: Error deleting keychain item: %i", status);
		}
		SecKeychainItemFreeContent(NULL, buffer);
		CFRelease(item);
	}
	return [pass autorelease];
}

/*************************************************************************/
#pragma mark -
#pragma mark INITIALIZATION METHODS
/*************************************************************************/

+ (PreferencesController *)sharedPrefs;
{
    if (! prefs) {
        prefs = [[self alloc] init];
    }
    return prefs;
}

- (id)init
{
    if ( (self = [super init]) ) {
        ITDebugLog(@"Preferences initialized.");
        df = [[NSUserDefaults standardUserDefaults] retain];
        
        effectClasses = [[ITWindowEffect effectClasses] retain];
        
        hotKeysArray = [[NSArray alloc] initWithObjects:@"PlayPause",
                                                       @"NextTrack",
                                                       @"PrevTrack",
                                                       @"FastForward",
                                                       @"Rewind",
                                                       @"ShowPlayer",
                                                       @"TrackInfo",
													   @"AlbumArt",
                                                       @"UpcomingSongs",
                                                       @"IncrementVolume",
                                                       @"DecrementVolume",
                                                       @"IncrementRating",
                                                       @"DecrementRating",
                                                       @"ToggleShuffle",
                                                       @"ToggleLoop",
													   @"ToggleShufflability",
                                                       @"PopupMenu",
                                                       @"SetRating0",
                                                       @"SetRating1",
                                                       @"SetRating2",
                                                       @"SetRating3",
                                                       @"SetRating4",
                                                       @"SetRating5",
                                                       nil];
        
        hotKeyNamesArray = [[NSArray alloc] initWithObjects:@"Play/Pause",
                                                       @"Next Track",
                                                       @"Previous Track",
                                                       @"Fast Forward",
                                                       @"Rewind",
                                                       @"Show Player",
                                                       @"Track Info",
													   @"Album Art",
                                                       @"Upcoming Songs",
                                                       @"Increment Volume",
                                                       @"Decrement Volume",
                                                       @"Increment Rating",
                                                       @"Decrement Rating",
                                                       @"Toggle Shuffle",
                                                       @"Toggle Loop",
													   @"Toggle Song Included In Shuffle",
                                                       @"Pop-up status menu",
                                                       [NSString stringWithUTF8String:"Set Rating: ☆☆☆☆☆"],
                                                       [NSString stringWithUTF8String:"Set Rating: ★☆☆☆☆"],
                                                       [NSString stringWithUTF8String:"Set Rating: ★★☆☆☆"],
                                                       [NSString stringWithUTF8String:"Set Rating: ★★★☆☆"],
                                                       [NSString stringWithUTF8String:"Set Rating: ★★★★☆"],
                                                       [NSString stringWithUTF8String:"Set Rating: ★★★★"],
                                                       nil];
        hotKeysDictionary = [[NSMutableDictionary alloc] init];
        controller = nil;
        
        [self setupWindow];  // Load in the nib, and perform any initial setup.
        [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    }
    return self;
}


/*************************************************************************/
#pragma mark -
#pragma mark ACCESSOR METHODS
/*************************************************************************/

- (id)controller
{
    return controller;
}

- (void)setController:(id)object
{
    [controller autorelease];
    controller = [object retain];
}


/*************************************************************************/
#pragma mark -
#pragma mark INSTANCE METHODS
/*************************************************************************/

- (BOOL)showPasswordPanel
{
    [passwordPanel setLevel:NSStatusWindowLevel];
    [passwordPanelOKButton setTitle:@"Connect"];
    [passwordPanelTitle setStringValue:@"Password Required"];
    [passwordPanelMessage setStringValue:[NSString stringWithFormat:@"Please enter a password for access to the MenuTunes player named %@ at %@.", [[[NetworkController sharedController] networkObject] serverName], [[NetworkController sharedController] remoteHost]]];
    [passwordPanel setLevel:NSStatusWindowLevel];
    [NSApp activateIgnoringOtherApps:YES];
    [passwordPanel center];
    [passwordPanel orderFrontRegardless];
    [passwordPanel makeKeyWindow];
    if ([NSApp runModalForWindow:passwordPanel]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)showInvalidPasswordPanel
{
    [passwordPanel setLevel:NSStatusWindowLevel];
    [passwordPanelOKButton setTitle:@"Retry"];
    [passwordPanelTitle setStringValue:@"Invalid Password"];
    [passwordPanelMessage setStringValue:[NSString stringWithFormat:@"The password entered for access to the MenuTunes player named %@ at %@ is invalid.  Please provide a new password.", [[[NetworkController sharedController] networkObject] serverName], [[NetworkController sharedController] remoteHost]]];
    [passwordPanel setLevel:NSStatusWindowLevel];
    [NSApp activateIgnoringOtherApps:YES];
    [passwordPanel center];
    [passwordPanel orderFrontRegardless];
    [passwordPanel makeKeyWindow];
    if ([NSApp runModalForWindow:passwordPanel]) {
        return YES;
    } else {
        return NO;
    }
}

- (IBAction)showPrefsWindow:(id)sender
{
    ITDebugLog(@"Showing preferences window.");
    if (!myItems) {  // If menu array does not exist yet, then the window hasn't been setup.
        ITDebugLog(@"Window doesn't exist, initial setup.");
        [self setupCustomizationTables];  // Setup the DnD manu config tables.
        [self setupMenuItems];  // Setup the arrays of menu items
        [self setupUI]; // Sets up additional UI
        [window setDelegate:self];
        [menuTableView reloadData];
        [hotKeysTableView reloadData];
        [hotKeysTableView setDoubleAction:@selector(hotKeysTableViewDoubleClicked:)];
        
        //Change the launch player checkbox to the proper name
        NS_DURING
            [launchPlayerAtLaunchCheckbox setTitle:[NSString stringWithFormat:@"Launch %@ when MenuTunes launches", [[controller currentRemote] playerSimpleName]]]; //This isn't localized...
        NS_HANDLER
            [controller networkError:localException];
        NS_ENDHANDLER
    }

    [self resetRemotePlayerTextFields];
    [launchAtLoginCheckbox becomeFirstResponder];
    [NSApp activateIgnoringOtherApps:YES];
	if (![window isVisible]) {
		[window center];
	}
    [window orderFrontRegardless];
    [window makeKeyWindow];
}

- (IBAction)changeGeneralSetting:(id)sender
{
    ITDebugLog(@"Changing general setting of tag %i.", [sender tag]);
    if ( [sender tag] == 1010) {
        ITSetApplicationLaunchOnLogin([[NSBundle mainBundle] bundlePath], SENDER_STATE);
    } else if ( [sender tag] == 1020) {
        [df setBool:SENDER_STATE forKey:@"LaunchPlayerWithMT"];
    } else if ( [sender tag] == 1030) {
        [df setInteger:[sender intValue] forKey:@"SongsInAdvance"];
        if ([[controller currentRemote] playerRunningState] == ITMTRemotePlayerRunning) {
            [[controller menuController] performSelector:@selector(rebuildSubmenus) withObject:nil afterDelay:0];
        }
    } else if ( [sender tag] == 1040) {
        // This will not be executed.  Song info always shows the title of the song.
        // [df setBool:SENDER_STATE forKey:@"showName"];
    } else if ( [sender tag] == 1050) {
        [df setBool:SENDER_STATE forKey:@"showArtist"];
    } else if ( [sender tag] == 1055) {
        [df setBool:SENDER_STATE forKey:@"showComposer"];
    } else if ( [sender tag] == 1060) {
        [df setBool:SENDER_STATE forKey:@"showAlbum"];
    } else if ( [sender tag] == 1070) {
        [df setBool:SENDER_STATE forKey:@"showTime"];
    } else if ( [sender tag] == 1080) {
        [df setBool:SENDER_STATE forKey:@"showTrackNumber"];
    } else if ( [sender tag] == 1085) {
        [df setBool:SENDER_STATE forKey:@"showPlayCount"];
    } else if ( [sender tag] == 1090) {
        [df setBool:SENDER_STATE forKey:@"showTrackRating"];
    } else if ( [sender tag] == 1100) {
        [df setBool:SENDER_STATE forKey:@"showAlbumArtwork"];
    } else if ( [sender tag] == 1110) {
        [df setBool:SENDER_STATE forKey:@"runScripts"];
        if (SENDER_STATE) {
            [runScriptsCheckbox setState:NSOnState];
            [showScriptsButton setEnabled:YES];
        } else {
            [showScriptsButton setEnabled:NO];
        }
    } else if ( [sender tag] == 1120) {
        mkdir([[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MenuTunes/Scripts"] UTF8String], 0744);
        [[NSWorkspace sharedWorkspace] openFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MenuTunes/Scripts"]];
    } else if ( [sender tag] == 6010) {
		//Toggle the other Audioscrobbler options
		[df setBool:SENDER_STATE forKey:@"audioscrobblerEnabled"];
		[audioscrobblerUseCacheCheckbox setEnabled:SENDER_STATE];
		[audioscrobblerUserTextField setEnabled:SENDER_STATE];
		[audioscrobblerPasswordTextField setEnabled:SENDER_STATE];
		if (SENDER_STATE) {
			[[AudioscrobblerController sharedController] attemptHandshake:NO];
		}
	} else if ( [sender tag ] == 6015) {
		//Here we create a new keychain item if needed and deletes the keychain item if the field is cleared.
		NSString *currentAccount = [df stringForKey:@"audioscrobblerUser"], *newAccount = [sender stringValue];
		if ([newAccount length] == 0) {
			[PreferencesController deleteKeychainItemForUser:currentAccount];
		} else if (![currentAccount isEqualToString:newAccount] && [[audioscrobblerPasswordTextField stringValue] length] > 0) {
			[df setObject:newAccount forKey:@"audioscrobblerUser"];
			if ([PreferencesController keychainItemExistsForUser:currentAccount]) {
				//Delete the current keychain item if there is one
				[PreferencesController deleteKeychainItemForUser:currentAccount];
			}
			[PreferencesController createKeychainItemForUser:newAccount andPassword:[audioscrobblerPasswordTextField stringValue]];
			[[AudioscrobblerController sharedController] attemptHandshake:YES];
		}
	} else if ( [sender tag ] == 6030) {
		//Here we set the password for an existing keychain item or we create a new keychain item.
		if ([[audioscrobblerUserTextField stringValue] length] > 0) {
			NSString *account = [df stringForKey:@"audioscrobblerUser"];
			if ([PreferencesController keychainItemExistsForUser:account]) {
				//Update the current keychain item
				[PreferencesController setKeychainItemPassword:[sender stringValue] forUser:account];
			} else if ([[sender stringValue] length] > 0 && [[audioscrobblerUserTextField stringValue] length]) {
				//Create a new keychain item
				[PreferencesController createKeychainItemForUser:account andPassword:[sender stringValue]];
			}
		}
	} else if ( [sender tag] == 6045) {
		[df setBool:SENDER_STATE forKey:@"audioscrobblerCacheSubmissions"];
	}
    [df synchronize];
}

- (IBAction)changeSharingSetting:(id)sender
{
    ITDebugLog(@"Changing sharing setting of tag %i.", [sender tag]);
    if ( [sender tag] == 5010 ) {
        BOOL state = SENDER_STATE;
        [df setBool:state forKey:@"enableSharing"];
        //Disable/enable the use of shared player options
        [useSharedMenuTunesCheckbox setEnabled:!state];
        [passwordTextField setEnabled:state];
        [nameTextField setEnabled:state];
        [selectSharedPlayerButton setEnabled:NO];
        [controller setServerStatus:state]; //Set server status
    } else if ( [sender tag] == 5015 ) {
        [df setObject:[sender stringValue] forKey:@"sharedPlayerName"];
        [[NetworkController sharedController] resetServerName];
    } else if ( [sender tag] == 5030 ) {
        //Set the server password
        const char *instring = [[sender stringValue] UTF8String];
        const char *password = "p4s5w0rdMT1.2";
        char *result;
        NSData *hashedPass, *passwordStringHash;
        if ([[sender stringValue] length] == 0) {
            [df setObject:[NSData data] forKey:@"sharedPlayerPassword"];
            return;
        }
        result = (char *)SHA1((unsigned char *)instring, strlen(instring), NULL);
        hashedPass = [NSData dataWithBytes:result length:strlen(result)];
        result = (char *)SHA1((unsigned char *)password, strlen(password), NULL);
        passwordStringHash = [NSData dataWithBytes:result length:strlen(result)];
        if (![hashedPass isEqualToData:passwordStringHash]) {
            [df setObject:hashedPass forKey:@"sharedPlayerPassword"];
            [sender setStringValue:@"p4s5w0rdMT1.2"];
        }
    } else if ( [sender tag] == 5040 ) {
        BOOL state = SENDER_STATE;
        [df setBool:state forKey:@"useSharedPlayer"];
        //Disable/enable the use of sharing options
        [shareMenuTunesCheckbox setEnabled:!state];
        [passwordTextField setEnabled:NO];
        [nameTextField setEnabled:NO];
        [selectSharedPlayerButton setEnabled:state];
        
        if (state && ([controller connectToServer] == 1)) {
            [selectedPlayerTextField setStringValue:[[[NetworkController sharedController] networkObject] serverName]];
            [locationTextField setStringValue:[[NetworkController sharedController] remoteHost]];
        } else {
            [selectedPlayerTextField setStringValue:@"No shared player selected."];
            [locationTextField setStringValue:@"-"];
            if ([[NetworkController sharedController] isConnectedToServer]) {
                [controller disconnectFromServer];
            }
            
        }
    } else if ( [sender tag] == 5050 ) {
        //If no player is selected in the table view, turn off OK button.
        if ([sender clickedRow] == -1 ) {
            [sharingPanelOKButton setEnabled:NO];
        } else {
            [sharingPanelOKButton setEnabled:YES];
        }
    } else if ( [sender tag] == 5051 ) {
        [df setObject:[sender stringValue] forKey:@"sharedPlayerHost"];
    } else if ( [sender tag] == 5060 ) {
        //Set OK button state
        if (([selectPlayerBox contentView] == zeroConfView && [sharingTableView selectedRow] == -1) ||
            ([selectPlayerBox contentView] == manualView && [[hostTextField stringValue] length] == 0)) {
            [sharingPanelOKButton setEnabled:NO];
        } else {
            [sharingPanelOKButton setEnabled:YES];
        }
        //Show selection sheet
        [NSApp beginSheet:selectPlayerSheet modalForWindow:window modalDelegate:self didEndSelector:NULL contextInfo:nil];
    } else if ( [sender tag] == 5100 ) {
        //Change view
        if ( ([sender indexOfItem:[sender selectedItem]] == 0) && ([selectPlayerBox contentView] != zeroConfView) ) {
            NSRect frame = [selectPlayerSheet frame];
            frame.origin.y -= 58;
            frame.size.height = 273;
            if ([sharingTableView selectedRow] == -1) {
                [sharingPanelOKButton setEnabled:NO];
            }
            [selectPlayerBox setContentView:zeroConfView];
            [selectPlayerSheet setFrame:frame display:YES animate:YES];
        } else if ( ([sender indexOfItem:[sender selectedItem]] == 1) && ([selectPlayerBox contentView] != manualView) ){
            NSRect frame = [selectPlayerSheet frame];
            frame.origin.y += 58;
            frame.size.height = 215;
            if ([[hostTextField stringValue] length] == 0) {
                [sharingPanelOKButton setEnabled:NO];
            } else {
                [sharingPanelOKButton setEnabled:YES];
            }
            [selectPlayerBox setContentView:manualView];
            [selectPlayerSheet setFrame:frame display:YES animate:YES];
            [hostTextField selectText:nil];
        }
    } else if ( [sender tag] == 5150 ) {
        const char *instring = [[sender stringValue] UTF8String];
        char *result;
        result = (char *)SHA1((unsigned char *)instring, strlen(instring), NULL);
        [df setObject:[NSData dataWithBytes:result length:strlen(result)] forKey:@"connectPassword"];
    } else if ( [sender tag] == 5110 ) {
        //Cancel
        [NSApp endSheet:selectPlayerSheet];
        [selectPlayerSheet orderOut:nil];
        if ([selectPlayerBox contentView] == manualView) {
            [hostTextField setStringValue:[df stringForKey:@"sharedPlayerHost"]];
        } else {
        }
    } else if ( [sender tag] == 5120 ) {
        //OK, try to connect
        [NSApp endSheet:selectPlayerSheet];
        [selectPlayerSheet orderOut:nil];
        
        [self changeSharingSetting:clientPasswordTextField];
        
        if ([selectPlayerBox contentView] == manualView) {
            [df setObject:[hostTextField stringValue] forKey:@"sharedPlayerHost"];
        } else {
            if ([sharingTableView selectedRow] > -1) {
                [df setObject:[NSString stringWithCString:inet_ntoa((*(struct sockaddr_in*)[[[[[[NetworkController sharedController] remoteServices] objectAtIndex:[sharingTableView selectedRow]] addresses] objectAtIndex:0] bytes]).sin_addr)] forKey:@"sharedPlayerHost"];
            }
        }
        
        if ([controller connectToServer] == 1) {
            [useSharedMenuTunesCheckbox setState:NSOnState];
            [selectedPlayerTextField setStringValue:[[[NetworkController sharedController] networkObject] serverName]];
            [locationTextField setStringValue:[[NetworkController sharedController] remoteHost]];
        } else {
            NSRunAlertPanel(@"Connection error.", @"The MenuTunes server you attempted to connect to was not responding. MenuTunes will revert back to the local player.", @"OK", nil, nil);
        }
    } else if ( [sender tag] == 6010 ) {
        //Cancel password entry
        [passwordPanel orderOut:nil];
        [NSApp stopModalWithCode:0];
    } else if ( [sender tag] == 6020 ) {
        //OK password entry, retry connect
        const char *instring = [[passwordPanelTextField stringValue] UTF8String];
        char *result;
        result = (char *)SHA1((unsigned char *)instring, strlen(instring), NULL);
        [df setObject:[NSData dataWithBytes:result length:strlen(result)] forKey:@"connectPassword"];
        [passwordPanel orderOut:nil];
        [NSApp stopModalWithCode:1];
    }
    [df synchronize];
}

- (IBAction)changeStatusWindowSetting:(id)sender
{
    StatusWindow *sw = (StatusWindow *)[StatusWindow sharedWindow];
    ITDebugLog(@"Changing status window setting of tag %i", [sender tag]);
    
    if ( [sender tag] == 2010) {
    
        BOOL entryEffectValid = YES;
        BOOL exitEffectValid  = YES;
                
        [df setInteger:[sender selectedRow] forKey:@"statusWindowVerticalPosition"];
        [df setInteger:[sender selectedColumn] forKey:@"statusWindowHorizontalPosition"];
        [sw setVerticalPosition:[sender selectedRow]];
        [sw setHorizontalPosition:[sender selectedColumn]];
        
        // Enable/disable the items in the popups.
        [self repopulateEffectPopupsForVerticalPosition:[sw verticalPosition]
                                     horizontalPosition:[sw horizontalPosition]];

        // Make sure the effects support the new position.  
        entryEffectValid = ( [self effect:[[sw entryEffect] class] 
                 supportsVerticalPosition:[sw verticalPosition]
                   withHorizontalPosition:[sw horizontalPosition]] );
        exitEffectValid  = ( [self effect:[[sw exitEffect] class] 
                 supportsVerticalPosition:[sw verticalPosition]
                   withHorizontalPosition:[sw horizontalPosition]] );
        
        if ( ! entryEffectValid ) {
            [appearanceEffectPopup selectItemAtIndex:[[appearanceEffectPopup menu] indexOfItemWithRepresentedObject:NSClassFromString(@"ITCutWindowEffect")]];
            [self setStatusWindowEntryEffect:NSClassFromString(@"ITCutWindowEffect")];
        } else {
            [appearanceEffectPopup selectItemAtIndex:[[appearanceEffectPopup menu] indexOfItemWithRepresentedObject:[[sw entryEffect] class]]];
        }
        
        if ( ! exitEffectValid ) {
            [vanishEffectPopup selectItemAtIndex:[[vanishEffectPopup menu] indexOfItemWithRepresentedObject:NSClassFromString(@"ITDissolveWindowEffect")]];
            [self setStatusWindowExitEffect:NSClassFromString(@"ITDissolveWindowEffect")];
        } else {
            [vanishEffectPopup selectItemAtIndex:[[vanishEffectPopup menu] indexOfItemWithRepresentedObject:[[sw exitEffect] class]]];
        }
        
        [(MainController *)controller showCurrentTrackInfo];
        
    } else if ( [sender tag] == 2020) {
    
        // Update screen selection.
		[[StatusWindow sharedWindow] setScreen:[[NSScreen screens] objectAtIndex:[sender indexOfSelectedItem]]];
		[df setInteger:[sender indexOfSelectedItem] forKey:@"statusWindowScreenIndex"];
        [(MainController *)controller showCurrentTrackInfo];
		
    } else if ( [sender tag] == 2030) {
    
        [self setStatusWindowEntryEffect:[[sender selectedItem] representedObject]];
        [(MainController *)controller showCurrentTrackInfo];
        
    } else if ( [sender tag] == 2040) {
    
        [self setStatusWindowExitEffect:[[sender selectedItem] representedObject]];
        [(MainController *)controller showCurrentTrackInfo];
        
    } else if ( [sender tag] == 2050) {
        float newTime = ( -([sender floatValue]) );
        [df setFloat:newTime forKey:@"statusWindowAppearanceSpeed"];
        [[sw entryEffect] setEffectTime:newTime];
    } else if ( [sender tag] == 2060) {
        float newTime = ( -([sender floatValue]) );
        [df setFloat:newTime forKey:@"statusWindowVanishSpeed"];
        [[sw exitEffect] setEffectTime:newTime];
    } else if ( [sender tag] == 2070) {
        [df setFloat:[sender floatValue] forKey:@"statusWindowVanishDelay"];
        [sw setExitDelay:[sender floatValue]];
    } else if ( [sender tag] == 2080) {
        [df setBool:SENDER_STATE forKey:@"showSongInfoOnChange"];
    } else if ( [sender tag] == 2090) {
        
        int setting = [sender indexOfSelectedItem];
        
        if ( setting == 0 ) {
            [(ITTSWBackgroundView *)[sw contentView] setBackgroundMode:ITTSWBackgroundApple];
            [backgroundColorWell  setEnabled:NO];
            [backgroundColorPopup setEnabled:NO];
        } else if ( setting == 1 ) {
            [(ITTSWBackgroundView *)[sw contentView] setBackgroundMode:ITTSWBackgroundReadable];
            [backgroundColorWell  setEnabled:NO];
            [backgroundColorPopup setEnabled:NO];
        } else if ( setting == 2 ) {
            [(ITTSWBackgroundView *)[sw contentView] setBackgroundMode:ITTSWBackgroundColored];
            [backgroundColorWell  setEnabled:YES];
            [backgroundColorPopup setEnabled:YES];
        }

        [df setInteger:setting forKey:@"statusWindowBackgroundMode"];
        [(MainController *)controller showCurrentTrackInfo];
        
    } else if ( [sender tag] == 2091) {
        [self setCustomColor:[sender color] updateWell:NO];
        [(MainController *)controller showCurrentTrackInfo];
    } else if ( [sender tag] == 2092) {
        
        int selectedItem = [sender indexOfSelectedItem];
        
        if ( selectedItem == 1 ) { // An NSPopUpButton in PullDown mode uses item 0 as its title.  Its first selectable item is 1.
            [self setCustomColor:[NSColor colorWithCalibratedRed:0.92549 green:0.686275 blue:0.0 alpha:1.0] updateWell:YES];
        } else if ( selectedItem == 2 ) {
            [self setCustomColor:[NSColor colorWithCalibratedRed:0.380392 green:0.670588 blue:0.0 alpha:1.0] updateWell:YES];
        } else if ( selectedItem == 3 ) {
            [self setCustomColor:[NSColor colorWithCalibratedRed:0.443137 green:0.231373 blue:0.619608 alpha:1.0] updateWell:YES];
        } else if ( selectedItem == 4 ) {
            [self setCustomColor:[NSColor colorWithCalibratedRed:0.831373 green:0.12549 blue:0.509804 alpha:1.0] updateWell:YES];
        } else if ( selectedItem == 5 ) {
            [self setCustomColor:[NSColor colorWithCalibratedRed:0.00784314 green:0.611765 blue:0.662745 alpha:1.0] updateWell:YES];
        } else {
            [self setCustomColor:[NSColor colorWithCalibratedWhite:0.15 alpha:0.70] updateWell:YES];
        }
        [(MainController *)controller showCurrentTrackInfo];

    } else if ( [sender tag] == 2095) {
        [df setInteger:[sender indexOfSelectedItem] forKey:@"statusWindowSizing"];
        [(MainController *)controller showCurrentTrackInfo];
    }
    
    [df synchronize];
}

- (void)registerDefaults
{
    ITDebugLog(@"Registering defaults.");
    [df setObject:[NSArray arrayWithObjects:
        @"trackInfo",
        @"separator",
        @"playPause",
        @"prevTrack",
        @"nextTrack",
        @"separator",
        @"playlists",
        @"upcomingSongs",
        @"separator",
        @"preferences",
		@"about",
        @"quit",
        nil] forKey:@"menu"];

    [df setInteger:MT_CURRENT_VERSION forKey:@"appVersion"];
    [df setInteger:5 forKey:@"SongsInAdvance"];
//  [df setBool:YES forKey:@"showName"];  // Song info will always show song title.
    [df setBool:YES forKey:@"showArtist"];
    [df setBool:YES forKey:@"showAlbumArtwork"];
    [df setBool:NO forKey:@"showAlbum"];
    [df setBool:NO forKey:@"showComposer"];
    [df setBool:NO forKey:@"showTime"];
    [df setBool:NO forKey:@"showToolTip"];

    [df setObject:@"ITCutWindowEffect" forKey:@"statusWindowAppearanceEffect"];
    [df setObject:@"ITDissolveWindowEffect" forKey:@"statusWindowVanishEffect"];
    [df setFloat:0.8 forKey:@"statusWindowAppearanceSpeed"];
    [df setFloat:0.8 forKey:@"statusWindowVanishSpeed"];
    [df setFloat:4.0 forKey:@"statusWindowVanishDelay"];
    [df setInteger:(int)ITWindowPositionBottom forKey:@"statusWindowVerticalPosition"];
    [df setInteger:(int)ITWindowPositionLeft forKey:@"statusWindowHorizontalPosition"];
	[df setInteger:0 forKey:@"statusWindowScreenIndex"];
    [[StatusWindow sharedWindow] setVerticalPosition:(int)ITWindowPositionBottom];
    [[StatusWindow sharedWindow] setHorizontalPosition:(int)ITWindowPositionLeft];
    [df setBool:YES forKey:@"showSongInfoOnChange"];
    
    [df setObject:[NSArchiver archivedDataWithRootObject:[NSColor blueColor]] forKey:@"statusWindowBackgroundColor"];
    
    [df synchronize];
    
    if (ITDoesApplicationLaunchOnLogin([[NSBundle mainBundle] bundlePath])) {
        [[StatusWindowController sharedController] showSetupQueryWindow];
    }
}

- (void)autoLaunchOK
{
    [(StatusWindow *)[StatusWindow sharedWindow] setLocked:NO];
    [[StatusWindow sharedWindow] vanish:self];
    [[StatusWindow sharedWindow] setIgnoresMouseEvents:YES];
    
    ITSetApplicationLaunchOnLogin([[NSBundle mainBundle] bundlePath], YES);
}

- (void)autoLaunchCancel
{
    [(StatusWindow *)[StatusWindow sharedWindow] setLocked:NO];
    [[StatusWindow sharedWindow] vanish:self];
    [[StatusWindow sharedWindow] setIgnoresMouseEvents:YES];
}

- (void)deletePressedInTableView:(NSTableView *)tableView
{
    if (tableView == menuTableView) {
        int selRow = [tableView selectedRow];
        ITDebugLog(@"Delete pressed in menu table view.");
        if (selRow != - 1) {
            NSString *object = [myItems objectAtIndex:selRow];
            
            if ([object isEqualToString:@"preferences"]) {
                NSBeep();
                return;
            }
            
            if (![object isEqualToString:@"separator"])
                [availableItems addObject:object];
            ITDebugLog(@"Removing object named %@", object);
            [myItems removeObjectAtIndex:selRow];
            [menuTableView reloadData];
            [allTableView reloadData];
        }
        [self changeMenus:self];
    }
}

- (void)resetRemotePlayerTextFields
{
    if ([[NetworkController sharedController] isConnectedToServer]) {
        [selectedPlayerTextField setStringValue:[[[NetworkController sharedController] networkObject] serverName]];
        [locationTextField setStringValue:[[NetworkController sharedController] remoteHost]];
    } else {
        [selectedPlayerTextField setStringValue:@"No shared player selected."];
        [locationTextField setStringValue:@"-"];
    }
}

/*************************************************************************/
#pragma mark -
#pragma mark HOTKEY SUPPORT METHODS
/*************************************************************************/

- (IBAction)clearHotKey:(id)sender
{
    [hotKeysDictionary setObject:[ITKeyCombo clearKeyCombo] forKey:[hotKeysArray objectAtIndex:[hotKeysTableView selectedRow]]];
    [df setObject:[[ITKeyCombo clearKeyCombo] plistRepresentation] forKey:[hotKeysArray objectAtIndex:[hotKeysTableView selectedRow]]];
    [controller setupHotKeys];
    [hotKeysTableView reloadData];
}

- (IBAction)editHotKey:(id)sender
{
    ITKeyComboPanel *panel = [ITKeyComboPanel sharedPanel];
    NSString *keyComboKey = [hotKeysArray objectAtIndex:[hotKeysTableView selectedRow]];
    ITKeyCombo *keyCombo;
    
    ITDebugLog(@"Setting key combo on hot key %@.", keyComboKey);
    [controller clearHotKeys];
    [panel setKeyCombo:[hotKeysDictionary objectForKey:[hotKeysArray objectAtIndex:[hotKeysTableView selectedRow]]]];
    [panel setKeyBindingName:[hotKeyNamesArray objectAtIndex:[hotKeysTableView selectedRow]]];
    if ([panel runModal] == NSOKButton) {
        NSEnumerator *keyEnumerator = [[hotKeysDictionary allKeys] objectEnumerator];
        NSString *nextKey;
        keyCombo = [panel keyCombo];
        
        //Check for duplicate key combo
        while ( (nextKey = [keyEnumerator nextObject]) ) {
            if ([[hotKeysDictionary objectForKey:nextKey] isEqual:keyCombo] &&
                ![keyCombo isEqual:[ITKeyCombo clearKeyCombo]]) {
                [hotKeysDictionary setObject:[ITKeyCombo clearKeyCombo]
                                   forKey:nextKey];
                [df setObject:[[ITKeyCombo clearKeyCombo] plistRepresentation]
                    forKey:nextKey];
            }
        }
        
        [hotKeysDictionary setObject:keyCombo forKey:keyComboKey];
        [df setObject:[keyCombo plistRepresentation] forKey:keyComboKey];
        [controller setupHotKeys];
        [hotKeysTableView reloadData];
        ITDebugLog(@"Set combo %@ on hot key %@.", keyCombo, keyComboKey);
    } else {
        ITDebugLog(@"Hot key setting on hot key %@ cancelled.", keyComboKey);
    }
}

- (void)hotKeysTableViewDoubleClicked:(id)sender
{
    if ([sender clickedRow] > -1) {
        [self editHotKey:sender];
    }
}

/*************************************************************************/
#pragma mark -
#pragma mark PRIVATE METHOD IMPLEMENTATIONS
/*************************************************************************/

- (void)audioscrobblerStatusChanged:(NSNotification *)note
{
	[audioscrobblerStatusTextField setStringValue:[[note userInfo] objectForKey:@"StatusString"]];
}

- (void)setupWindow
{
    ITDebugLog(@"Loading Preferences.nib.");
    if (![NSBundle loadNibNamed:@"Preferences" owner:self]) {
        ITDebugLog(@"Failed to load Preferences.nib.");
        NSBeep();
        return;
    }
}

- (void)setupCustomizationTables
{
    NSImageCell *imgCell = [[[NSImageCell alloc] initImageCell:nil] autorelease];
    ITDebugLog(@"Setting up table views.");
    // Set the table view cells up
    [imgCell setImageScaling:NSScaleNone];
    [[menuTableView tableColumnWithIdentifier:@"submenu"] setDataCell:imgCell];
    [[allTableView tableColumnWithIdentifier:@"submenu"] setDataCell:imgCell];

    // Register for drag and drop
    [menuTableView registerForDraggedTypes:[NSArray arrayWithObjects:
        @"MenuTableViewPboardType",
        @"AllTableViewPboardType",
        nil]];
    [allTableView registerForDraggedTypes:[NSArray arrayWithObjects:
        @"MenuTableViewPboardType",
        @"AllTableViewPboardType",
        nil]];
}

- (void)setupMenuItems
{
    NSEnumerator *itemEnum;
    id            anItem;
    ITDebugLog(@"Setting up table view arrays.");
    // Set the list of items you can have.
    availableItems = [[NSMutableArray alloc] initWithObjects:
        @"separator",
        @"trackInfo",
        @"upcomingSongs",
        @"playlists",
        @"artists",
        @"albums",
        @"eqPresets",
        @"songRating",
        @"playPause",
        @"nextTrack",
        @"prevTrack",
        @"fastForward",
        @"rewind",
        @"showPlayer",
		@"about",
        @"quit",
        nil];
    
    // Get our preferred menu
    myItems = [[df arrayForKey:@"menu"] mutableCopy];
    
    // Delete items in the availableItems array that are already part of the menu
    itemEnum = [myItems objectEnumerator];
    while ( (anItem = [itemEnum nextObject]) ) {
        if (![anItem isEqualToString:@"separator"]) {
            [availableItems removeObject:anItem];
        }
    }
    
    // Items that show should a submenu image
    submenuItems = [[NSArray alloc] initWithObjects:
        @"upcomingSongs",
        @"playlists",
        @"artists",
        @"albums",
        @"eqPresets",
        @"songRating",
        nil];
}

- (void)setupUI
{
    NSEnumerator   *keyArrayEnum;
    NSString       *serverName;
    NSData         *colorData;
    int selectedBGStyle;
    id anItem;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioscrobblerStatusChanged:) name:@"AudioscrobblerStatusChanged" object:nil];
	if ([df boolForKey:@"audioscrobblerEnabled"]) {
		NSString *status = [[AudioscrobblerController sharedController] lastStatus];
		[audioscrobblerStatusTextField setStringValue:(status == nil) ? @"Idle" : status];
	}
	
    [df setInteger:MT_CURRENT_VERSION forKey:@"appVersion"];
    
    ITDebugLog(@"Setting up preferences UI.");
    // Fill in the number of songs in advance to show field
    [songsInAdvance setIntValue:[df integerForKey:@"SongsInAdvance"]];
    
    // Fill hot key array
    keyArrayEnum = [hotKeysArray objectEnumerator];
    
    while ( (anItem = [keyArrayEnum nextObject]) ) {
        if ([df objectForKey:anItem]) {
            ITDebugLog(@"Setting up \"%@\" hot key.", anItem);
            [hotKeysDictionary setObject:[ITKeyCombo keyComboWithPlistRepresentation:[df objectForKey:anItem]] forKey:anItem];
        } else {
            [hotKeysDictionary setObject:[ITKeyCombo clearKeyCombo] forKey:anItem];
        }
    }
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupScreenPopup) name:NSApplicationDidChangeScreenParametersNotification object:nil];
	[self setupScreenPopup];
	
    ITDebugLog(@"Setting up track info checkboxes.");
    // Check current track info buttons
    [albumCheckbox setState:[df boolForKey:@"showAlbum"] ? NSOnState : NSOffState];
    [nameCheckbox setState:NSOnState];  // Song info will ALWAYS show song title.
    [nameCheckbox setEnabled:NO];  // Song info will ALWAYS show song title.
    [artistCheckbox setState:[df boolForKey:@"showArtist"] ? NSOnState : NSOffState];
    [composerCheckbox setState:[df boolForKey:@"showComposer"] ? NSOnState : NSOffState];
    [trackTimeCheckbox setState:[df boolForKey:@"showTime"] ? NSOnState : NSOffState];
    [trackNumberCheckbox setState:[df boolForKey:@"showTrackNumber"] ? NSOnState : NSOffState];
    [playCountCheckbox setState:[df boolForKey:@"showPlayCount"] ? NSOnState : NSOffState];
    [ratingCheckbox setState:[df boolForKey:@"showTrackRating"] ? NSOnState : NSOffState];
    [albumArtworkCheckbox setState:[df boolForKey:@"showAlbumArtwork"] ? NSOnState : NSOffState];
    
    if ([df boolForKey:@"runScripts"]) {
        [runScriptsCheckbox setState:NSOnState];
        [showScriptsButton setEnabled:YES];
    } else {
        [showScriptsButton setEnabled:NO];
    }
    
    // Set the launch at login checkbox state
    ITDebugLog(@"Setting launch at login state.");
    if (ITDoesApplicationLaunchOnLogin([[NSBundle mainBundle] bundlePath])) {
        [launchAtLoginCheckbox setState:NSOnState];
    }
    
    // Set the launch player checkbox state
    ITDebugLog(@"Setting launch player with MenuTunes state.");
    [launchPlayerAtLaunchCheckbox setState:[df boolForKey:@"LaunchPlayerWithMT"] ? NSOnState : NSOffState];
    
    // Setup the positioning controls
    [positionMatrix selectCellAtRow:[df integerForKey:@"statusWindowVerticalPosition"]
                             column:[df integerForKey:@"statusWindowHorizontalPosition"]];
    
    // Setup effects controls
    // Populate the effects popups
    [appearanceEffectPopup setAutoenablesItems:NO];
    [vanishEffectPopup     setAutoenablesItems:NO];
    [self repopulateEffectPopupsForVerticalPosition:[df integerForKey:@"statusWindowVerticalPosition"] 
                                 horizontalPosition:[df integerForKey:@"statusWindowHorizontalPosition"]];
    
    // Attempt to find the pref'd effect in the list.
    // If it's not there, use cut/dissolve.
    if ( [effectClasses containsObject:NSClassFromString([df stringForKey:@"statusWindowAppearanceEffect"])] ) {
        [appearanceEffectPopup selectItemAtIndex:[effectClasses indexOfObject:NSClassFromString([df stringForKey:@"statusWindowAppearanceEffect"])]];
    } else {
        [appearanceEffectPopup selectItemAtIndex:[effectClasses indexOfObject:NSClassFromString(@"ITCutWindowEffect")]];
    }
    
    if ( [effectClasses containsObject:NSClassFromString([df stringForKey:@"statusWindowVanishEffect"])] ) {
        [vanishEffectPopup selectItemAtIndex:[effectClasses indexOfObject:NSClassFromString([df stringForKey:@"statusWindowVanishEffect"])]];
    } else {
        [vanishEffectPopup selectItemAtIndex:[effectClasses indexOfObject:NSClassFromString(@"ITCutWindowEffect")]];
    }
    
    [appearanceSpeedSlider setFloatValue:( -([df floatForKey:@"statusWindowAppearanceSpeed"]) )];
    [vanishSpeedSlider     setFloatValue:( -([df floatForKey:@"statusWindowVanishSpeed"]) )];
    [vanishDelaySlider     setFloatValue:[df floatForKey:@"statusWindowVanishDelay"]];

    // Setup General Controls
    selectedBGStyle = [df integerForKey:@"statusWindowBackgroundMode"];
    [backgroundStylePopup selectItem:[backgroundStylePopup itemAtIndex:[backgroundStylePopup indexOfItemWithTag:selectedBGStyle]]];

    if ( selectedBGStyle == ITTSWBackgroundColored ) {
        [backgroundColorWell  setEnabled:YES];
        [backgroundColorPopup setEnabled:YES];
    } else {
        [backgroundColorWell  setEnabled:NO];
        [backgroundColorPopup setEnabled:NO];
    }

    colorData = [df dataForKey:@"statusWindowBackgroundColor"];

    if ( colorData ) {
        [backgroundColorWell setColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData]];
    } else {
        [backgroundColorWell setColor:[NSColor blueColor]];
    }
    
    [showOnChangeCheckbox setState:([df boolForKey:@"showSongInfoOnChange"] ? NSOnState : NSOffState)];
    
    [windowSizingPopup selectItem:[windowSizingPopup itemAtIndex:[windowSizingPopup indexOfItemWithTag:[df integerForKey:@"statusWindowSizing"]]]];

    // Setup the sharing controls
    if ([df boolForKey:@"enableSharing"]) {
        [shareMenuTunesCheckbox setState:NSOnState];
        [useSharedMenuTunesCheckbox setEnabled:NO];
        [selectSharedPlayerButton setEnabled:NO];
        [passwordTextField setEnabled:YES];
        [nameTextField setEnabled:YES];
    } else if ([df boolForKey:@"useSharedPlayer"]) {
        [useSharedMenuTunesCheckbox setState:NSOnState];
        [shareMenuTunesCheckbox setEnabled:NO];
        [selectSharedPlayerButton setEnabled:YES];
    }
    
	//Setup the Audioscrobbler controls
	if ([df boolForKey:@"audioscrobblerEnabled"]) {
		[audioscrobblerEnabledCheckbox setState:NSOnState];
		[audioscrobblerUserTextField setEnabled:YES];
		[audioscrobblerPasswordTextField setEnabled:YES];
		[audioscrobblerUseCacheCheckbox setEnabled:YES];
	} else {
		[audioscrobblerUserTextField setEnabled:NO];
		[audioscrobblerPasswordTextField setEnabled:NO];
		[audioscrobblerUseCacheCheckbox setEnabled:NO];
	}
	NSString *audioscrobblerUser = [df stringForKey:@"audioscrobblerUser"];
	if (audioscrobblerUser != nil && [audioscrobblerUser length] > 0 && [PreferencesController keychainItemExistsForUser:audioscrobblerUser]) {
		NSString *password = [PreferencesController getKeychainItemPasswordForUser:audioscrobblerUser];
		[audioscrobblerUserTextField setStringValue:audioscrobblerUser];
		if (password != nil) {
			[audioscrobblerPasswordTextField setStringValue:password];
		}
	}
	[audioscrobblerUseCacheCheckbox setState:[df boolForKey:@"audioscrobblerCacheSubmissions"]];
	
    [[NSNotificationCenter defaultCenter] addObserver:sharingTableView selector:@selector(reloadData) name:@"ITMTFoundNetService" object:nil];
    
    serverName = [df stringForKey:@"sharedPlayerName"];
    if (!serverName || [serverName length] == 0) {
        serverName = @"MenuTunes Shared Player";
    }
    [nameTextField setStringValue:serverName];
    
    [selectPlayerBox setContentView:zeroConfView];
    if ([[df dataForKey:@"sharedPlayerPassword"] length] > 0) {
        [passwordTextField setStringValue:@"p4s5w0rdMT1.2"];
    } else {
        [passwordTextField setStringValue:@""];
    }
    if ([df stringForKey:@"sharedPlayerHost"]) {
        [hostTextField setStringValue:[df stringForKey:@"sharedPlayerHost"]];
    }
    
    if ([[NetworkController sharedController] isConnectedToServer]) {
        [selectedPlayerTextField setStringValue:[[[NetworkController sharedController] networkObject] serverName]];
        [locationTextField setStringValue:[[NetworkController sharedController] remoteHost]];
    } else {
        [selectedPlayerTextField setStringValue:@"No shared player selected."];
        [locationTextField setStringValue:@"-"];
    }
}

- (void)setupScreenPopup
{
	ITDebugLog(@"Setting up screen popup");
	NSArray *screens = [NSScreen screens];
	if ([screens count] > 1) {
		int i, index = [df integerForKey:@"statusWindowScreenIndex"];
		[screenPopup setEnabled:YES];
		for (i = 0; i < [screens count]; i++) {
			NSScreen *screen = [screens objectAtIndex:i];
			if (![screen isEqual:[NSScreen mainScreen]]) {
				[screenPopup addItemWithTitle:[NSString stringWithFormat:@"Screen %i", i + 1]];
			}
		}
		[screenPopup selectItemAtIndex:index];
		[[StatusWindow sharedWindow] setScreen:[[NSScreen screens] objectAtIndex:index]];
	} else {
		while ([screenPopup numberOfItems] > 1) {
			[screenPopup removeItemAtIndex:1];
		}
		[screenPopup setEnabled:NO];
		[[StatusWindow sharedWindow] setScreen:[NSScreen mainScreen]];
	}
}

- (void)setStatusWindowEntryEffect:(Class)effectClass
{
    StatusWindow *sw = (StatusWindow *)[StatusWindow sharedWindow];
    
    float time = ([df floatForKey:@"statusWindowAppearanceSpeed"] ? [df floatForKey:@"statusWindowAppearanceSpeed"] : 0.8);
    [df setObject:NSStringFromClass(effectClass) forKey:@"statusWindowAppearanceEffect"];
    
    [sw setEntryEffect:[[[effectClass alloc] initWithWindow:sw] autorelease]];
    [[sw entryEffect] setEffectTime:time];
}

- (void)setStatusWindowExitEffect:(Class)effectClass
{
    StatusWindow *sw = (StatusWindow *)[StatusWindow sharedWindow];
    
    float time = ([df floatForKey:@"statusWindowVanishSpeed"] ? [df floatForKey:@"statusWindowVanishSpeed"] : 0.8);
    [df setObject:NSStringFromClass(effectClass) forKey:@"statusWindowVanishEffect"];
    
    [sw setExitEffect:[[[effectClass alloc] initWithWindow:sw] autorelease]];
    [[sw exitEffect] setEffectTime:time];
}

- (void)setCustomColor:(NSColor *)color updateWell:(BOOL)update
{
    [(ITTSWBackgroundView *)[[StatusWindow sharedWindow] contentView] setBackgroundColor:color];
    [df setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"statusWindowBackgroundColor"];
    
    if ( update ) {
        [backgroundColorWell setColor:color];
    }
}

- (void)repopulateEffectPopupsForVerticalPosition:(ITVerticalWindowPosition)vPos horizontalPosition:(ITHorizontalWindowPosition)hPos
{
    NSEnumerator *effectEnum = [effectClasses objectEnumerator];
    id anItem;
    
    [appearanceEffectPopup removeAllItems];
    [vanishEffectPopup     removeAllItems];
    
    while ( (anItem = [effectEnum nextObject]) ) {
        [appearanceEffectPopup addItemWithTitle:[anItem effectName]];
        [vanishEffectPopup     addItemWithTitle:[anItem effectName]];
        
        [[appearanceEffectPopup lastItem] setRepresentedObject:anItem];
        [[vanishEffectPopup     lastItem] setRepresentedObject:anItem];
        
        if ( [self effect:anItem supportsVerticalPosition:vPos withHorizontalPosition:hPos] ) {
            [[appearanceEffectPopup lastItem] setEnabled:YES];
            [[vanishEffectPopup     lastItem] setEnabled:YES];
        } else {
            [[appearanceEffectPopup lastItem] setEnabled:NO];
            [[vanishEffectPopup     lastItem] setEnabled:NO];
        }
    }
    
}

- (BOOL)effect:(Class)effectClass supportsVerticalPosition:(ITVerticalWindowPosition)vPos withHorizontalPosition:(ITHorizontalWindowPosition)hPos
{
    BOOL valid = NO;
    
    if ( vPos == ITWindowPositionTop ) {
        if ( hPos == ITWindowPositionLeft ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Top"] objectForKey:@"Left"] boolValue] ) ;
        } else if ( hPos == ITWindowPositionCenter ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Top"] objectForKey:@"Center"] boolValue] );
        } else if ( hPos == ITWindowPositionRight ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Top"] objectForKey:@"Right"] boolValue] );
        }
    } else if ( vPos == ITWindowPositionMiddle ) {
        if ( hPos == ITWindowPositionLeft ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Middle"] objectForKey:@"Left"] boolValue] );
        } else if ( hPos == ITWindowPositionCenter ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Middle"] objectForKey:@"Center"] boolValue] );
        } else if ( hPos == ITWindowPositionRight ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Middle"] objectForKey:@"Right"] boolValue] );
        }
    } else if ( vPos == ITWindowPositionBottom ) {
        if ( hPos == ITWindowPositionLeft ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Bottom"] objectForKey:@"Left"] boolValue] );
        } else if ( hPos == ITWindowPositionCenter ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Bottom"] objectForKey:@"Center"] boolValue] );
        } else if ( hPos == ITWindowPositionRight ) {
            valid = ( [[[[effectClass supportedPositions] objectForKey:@"Bottom"] objectForKey:@"Right"] boolValue] );
        }
    }
    
    return valid;
}

- (IBAction)changeMenus:(id)sender
{
    ITDebugLog(@"Synchronizing menus");
    [df setObject:myItems forKey:@"menu"];
    [df synchronize];
    
    [[controller menuController] performSelector:@selector(rebuildSubmenus) withObject:nil afterDelay:0.0];
    
    //If we're connected over a network, refresh the menu immediately
    if ([[NetworkController sharedController] isConnectedToServer]) {
        [controller timerUpdate];
    }
}


/*************************************************************************/
#pragma mark -
#pragma mark NSWindow DELEGATE METHODS
/*************************************************************************/

- (void)windowWillClose:(NSNotification *)note
{
    [(MainController *)controller closePreferences]; 
}

/*************************************************************************/
#pragma mark -
#pragma mark NSTextField DELEGATE METHODS
/*************************************************************************/

- (void)controlTextDidChange:(NSNotification*)note
{
    if ([note object] == hostTextField) {
        if ([[hostTextField stringValue] length] == 0) {
            [sharingPanelOKButton setEnabled:NO];
        } else {
            [sharingPanelOKButton setEnabled:YES];
        }
    }
}

/*************************************************************************/
#pragma mark -
#pragma mark NSTableView DATASOURCE METHODS
/*************************************************************************/

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == menuTableView) {
        return [myItems count];
    } else if (aTableView == allTableView) {
        return [availableItems count];
    } else if (aTableView == hotKeysTableView) {
        return [hotKeysArray count];
    } else {
        return [[[NetworkController sharedController] remoteServices] count];
    }
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (aTableView == menuTableView) {
        NSString *object = [myItems objectAtIndex:rowIndex];
        if ([[aTableColumn identifier] isEqualToString:@"name"]) {
            if ([object isEqualToString:@"showPlayer"]) {
                NSString *string = nil;
                NS_DURING
                    string = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"show", @"Show"), [[controller currentRemote] playerSimpleName]];
                NS_HANDLER
                    [controller networkError:localException];
                NS_ENDHANDLER
                return string;
            }
            return NSLocalizedString(object, @"ERROR");
        } else {
            if ([submenuItems containsObject:object])
            {
                return [NSImage imageNamed:@"submenu"];
            } else {
                return nil;
            }
        }
    } else if (aTableView == allTableView) {
        NSString *object = [availableItems objectAtIndex:rowIndex];
        if ([[aTableColumn identifier] isEqualToString:@"name"]) {
            if ([object isEqualToString:@"showPlayer"]) {
                NSString *string = nil;
                NS_DURING
                    string = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"show", @"Show"), [[controller currentRemote] playerSimpleName]];
                NS_HANDLER
                    [controller networkError:localException];
                NS_ENDHANDLER
                return string;
            }
            return NSLocalizedString(object, @"ERROR");
        } else {
            if ([submenuItems containsObject:object]) {
                return [NSImage imageNamed:@"submenu"];
            } else {
                return nil;
            }
        }
    } else if (aTableView == hotKeysTableView) {
        if ([[aTableColumn identifier] isEqualToString:@"name"]) {
            return [hotKeyNamesArray objectAtIndex:rowIndex];
        } else {
            return [[hotKeysDictionary objectForKey:[hotKeysArray objectAtIndex:rowIndex]] description];
        }
    } else {
        return [[[[NetworkController sharedController] remoteServices] objectAtIndex:rowIndex] name];
    }
}

- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
    if (tableView == menuTableView) {
        [pboard declareTypes:[NSArray arrayWithObjects:@"MenuTableViewPboardType", nil] owner:self];
        [pboard setString:[[rows objectAtIndex:0] stringValue] forType:@"MenuTableViewPboardType"];
        return YES;
    }
    
    if (tableView == allTableView) {
        [pboard declareTypes:[NSArray arrayWithObjects:@"AllTableViewPboardType", nil] owner:self];
        [pboard setString:[[rows objectAtIndex:0] stringValue] forType:@"AllTableViewPboardType"];
        return YES;
    }
    return NO;
}

- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pb;
    int dragRow;
    NSString *dragData, *temp;
    
    pb = [info draggingPasteboard];
    
    if ([[pb types] containsObject:@"MenuTableViewPboardType"]) {
        dragData = [pb stringForType:@"MenuTableViewPboardType"];
        dragRow = [dragData intValue];
        temp = [myItems objectAtIndex:dragRow];
        
        if (tableView == menuTableView) {
            [myItems insertObject:temp atIndex:row];
            if (row > dragRow) {
                [myItems removeObjectAtIndex:dragRow];
            } else {
                [myItems removeObjectAtIndex:dragRow + 1];
            }
        } else if (tableView == allTableView) {
            if (![temp isEqualToString:@"separator"]) {
                [availableItems addObject:temp];
            }
            [myItems removeObjectAtIndex:dragRow];
        }
    } else if ([[pb types] containsObject:@"AllTableViewPboardType"]) {
        dragData = [pb stringForType:@"AllTableViewPboardType"];
        dragRow = [dragData intValue];
        temp = [availableItems objectAtIndex:dragRow];
        
        [myItems insertObject:temp atIndex:row];
        
        if (![temp isEqualToString:@"separator"]) {
            [availableItems removeObjectAtIndex:dragRow];
        }
    }
    
    [menuTableView reloadData];
    [allTableView reloadData];
    [self changeMenus:self];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (tableView == allTableView) {
        if ([[[info draggingPasteboard] types] containsObject:@"AllTableViewPboardType"]) {
            return NSDragOperationNone;
        }
        
        if ([[[info draggingPasteboard] types] containsObject:@"MenuTableViewPboardType"]) {
            NSString *item = [myItems objectAtIndex:[[[info draggingPasteboard] stringForType:@"MenuTableViewPboardType"] intValue]];
            if ([item isEqualToString:@"preferences"] || [item isEqualToString:@"quit"]) {
                return NSDragOperationNone;
            }
        }
        
        [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationGeneric;
    }
    
    if (operation == NSTableViewDropOn || row == -1)
    {
        return NSDragOperationNone;
    }
    return NSDragOperationGeneric;
}


/*************************************************************************/
#pragma mark -
#pragma mark DEALLOCATION METHODS
/*************************************************************************/

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [hotKeysArray release];
    [hotKeysDictionary release];
    [effectClasses release];
    [menuTableView setDataSource:nil];
    [allTableView setDataSource:nil];
    [controller release];
    [availableItems release];
    [submenuItems release];
    [myItems release];
    [df release];
	[super dealloc];
}

@end
