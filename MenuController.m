//
//  MenuController.m
//  MenuTunes
//
//  Created by Joseph Spiros on Wed Apr 30 2003.
//  Copyright (c) 2003 iThink Software. All rights reserved.
//

#import "MenuController.h"
#import "NewMainController.h"

@interface MenuController (SubmenuMethods)
- (NSMenu *)ratingMenu;
- (NSMenu *)upcomingSongsMenu;
- (NSMenu *)playlistsMenu;
- (NSMenu *)eqMenu;
@end

@implementation MenuController

- (id)init
{
    if ( (self = [super init]) ) {
        _menuLayout = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

- (NSMenu *)menu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSArray *menuArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"menu"];
    NSEnumerator *enumerator = [menuArray objectEnumerator];
    NSString *nextObject;
    NSMenuItem *tempItem;
    
    //Get the current playlist, track index, etc.
    currentRemote = [[MainController sharedController] currentRemote];
    _currentPlaylist = [currentRemote currentPlaylistIndex];
    _currentTrack = [currentRemote currentSongIndex];
    _playingRadio = ([currentRemote currentPlaylistClass] == ITMTRemotePlayerRadioPlaylist);
    
    //create our menu
    while ( (nextObject = [enumerator nextObject]) ) {
        //Main menu items
        if ([nextObject isEqualToString:@"Play/Pause"]) {
            tempItem = [menu addItemWithTitle:@"Play"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            [tempItem setTag:MTMenuPlayPauseItem];
            [tempItem setTarget:self];
            
            switch ([currentRemote playerPlayingState]) {
                case ITMTRemotePlayerPlaying:
                    [tempItem setTitle:@"Pause"];
                break;
                case ITMTRemotePlayerRewinding:
                case ITMTRemotePlayerForwarding:
                    [tempItem setTitle:@"Resume"];
                break;
                default:
                break;
            }
        } else if ([nextObject isEqualToString:@"Next Track"]) {
            tempItem = [menu addItemWithTitle:@"Next Track"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            if (_currentPlaylist) {
                [tempItem setTag:MTMenuNextTrackItem];
                [tempItem setTarget:self];
            }
        } else if ([nextObject isEqualToString:@"Previous Track"]) {
            tempItem = [menu addItemWithTitle:@"Previous Track"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            if (_currentPlaylist) {
                [tempItem setTag:MTMenuPreviousTrackItem];
                [tempItem setTarget:self];
            }
        } else if ([nextObject isEqualToString:@"Fast Forward"]) {
            tempItem = [menu addItemWithTitle:@"Fast Forward"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            if (_currentPlaylist) {
                [tempItem setTag:MTMenuFastForwardItem];
                [tempItem setTarget:self];
            }
        } else if ([nextObject isEqualToString:@"Rewind"]) {
            tempItem = [menu addItemWithTitle:@"Rewind"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            if (_currentPlaylist) {
                [tempItem setTag:MTMenuRewindItem];
                [tempItem setTarget:self];
            }
        } else if ([nextObject isEqualToString:@"Preferences"]) {
            tempItem = [menu addItemWithTitle:@"Preferences..."
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            [tempItem setTag:MTMenuPreferencesItem];
            [tempItem setTarget:self];
        } else if ([nextObject isEqualToString:@"Quit"]) {
            tempItem = [menu addItemWithTitle:@"Quit"
                    action:@selector(performMainMenuAction:)
                    keyEquivalent:@""];
            [tempItem setTag:MTMenuQuitItem];
            [tempItem setTarget:self];
        } else if ([nextObject isEqualToString:@"Current Track Info"]) {
            //Handle playing radio too
            if (_currentPlaylist) {
                NSString *title = [currentRemote currentSongTitle];
                
                [menu addItemWithTitle:@"Now Playing" action:NULL keyEquivalent:@""];
                
                if ([title length] > 0) {
                    [menu addItemWithTitle:[NSString stringWithFormat:@"	 %@", title] action:nil keyEquivalent:@""];
                }
                //Gotta add artist, album, track, time, etc, blah, blah, blah...
            } else {
                [menu addItemWithTitle:@"No Song" action:NULL keyEquivalent:@""];
            }
        } else if ([nextObject isEqualToString:@"<separator>"]) {
            [menu addItem:[NSMenuItem separatorItem]];
        //Submenu items
        } else if ([nextObject isEqualToString:@"Song Rating"]) {
            tempItem = [menu addItemWithTitle:@"Song Rating"
                    action:nil
                    keyEquivalent:@""];
            [tempItem setSubmenu:[self ratingMenu]];
            if (_playingRadio || !_currentPlaylist) {
                [tempItem setEnabled:NO];
            }
        } else if ([nextObject isEqualToString:@"Upcoming Songs"]) {
            tempItem = [menu addItemWithTitle:@"Upcoming Songs"
                    action:nil
                    keyEquivalent:@""];
            [tempItem setSubmenu:[self upcomingSongsMenu]];
            if (_playingRadio || !_currentPlaylist) {
                [tempItem setEnabled:NO];
            }
        } else if ([nextObject isEqualToString:@"Playlists"]) {
            tempItem = [menu addItemWithTitle:@"Playlists"
                    action:nil
                    keyEquivalent:@""];
            [tempItem setSubmenu:[self playlistsMenu]];
        } else if ([nextObject isEqualToString:@"EQ Presets"]) {
            tempItem = [menu addItemWithTitle:@"EQ Presets"
                    action:nil
                    keyEquivalent:@""];
            [tempItem setSubmenu:[self eqMenu]];
        }
    }
    
    [_currentMenu release];
    _currentMenu = menu;
    return _currentMenu;
}

- (NSMenu *)menuForNoPlayer
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *tempItem;
    tempItem = [menu addItemWithTitle:[NSString stringWithFormat:@"Open %@", [[[MainController sharedController] currentRemote] playerSimpleName]] action:@selector(performMainMenuAction:) keyEquivalent:@""];
    [tempItem setTag:MTMenuShowPlayerItem];
    [tempItem setTarget:self];
    [menu addItem:[NSMenuItem separatorItem]];
    tempItem = [menu addItemWithTitle:@"Preferences" action:@selector(performMainMenuAction:) keyEquivalent:@""];
    [tempItem setTag:MTMenuPreferencesItem];
    [tempItem setTarget:self];
    tempItem = [menu addItemWithTitle:@"Quit" action:@selector(performMainMenuAction:) keyEquivalent:@""];
    [tempItem setTag:MTMenuQuitItem];
    [tempItem setTarget:self];
    return [menu autorelease];
}

- (NSMenu *)ratingMenu
{
    NSMenu *ratingMenu = [[NSMenu alloc] initWithTitle:@""];
    
    if (_currentPlaylist && !_playingRadio) {
        NSEnumerator *itemEnum;
        id  anItem;
        int itemTag = 0;
        SEL itemSelector = @selector(performRatingMenuAction:);
        
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"☆☆☆☆☆"] action:nil keyEquivalent:@""];
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"★☆☆☆☆"] action:nil keyEquivalent:@""];
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"★★☆☆☆"] action:nil keyEquivalent:@""];
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"★★★☆☆"] action:nil keyEquivalent:@""];
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"★★★★☆"] action:nil keyEquivalent:@""];
        [ratingMenu addItemWithTitle:[NSString stringWithUTF8String:"★★★★★"] action:nil keyEquivalent:@""];
        
        [[ratingMenu itemAtIndex:([currentRemote currentSongRating] * 5)] setState:NSOnState];
        
        itemEnum = [[ratingMenu itemArray] objectEnumerator];
        while ( (anItem = [itemEnum nextObject]) ) {
            [anItem setAction:itemSelector];
            [anItem setTarget:self];
            [anItem setTag:itemTag];
            itemTag += 20;
        }
    }
    
    return [ratingMenu autorelease];
}

- (NSMenu *)upcomingSongsMenu
{
    NSMenu *upcomingSongsMenu = [[NSMenu alloc] initWithTitle:@""];
    int numSongs = [currentRemote numberOfSongsInPlaylistAtIndex:_currentPlaylist];
    int numSongsInAdvance = [[NSUserDefaults standardUserDefaults] integerForKey:@"SongsInAdvance"];
    
    if (_currentPlaylist && !_playingRadio) {
        if (numSongs > 0) {
            int i;
            
            for (i = _currentTrack + 1; i <= _currentTrack + numSongsInAdvance; i++) {
                if (i <= numSongs) {
                    NSString *curSong = [currentRemote songTitleAtIndex:i];
                    NSMenuItem *songItem;
                    songItem = [upcomingSongsMenu addItemWithTitle:curSong action:@selector(performUpcomingSongsMenuAction:) keyEquivalent:@""];
                    [songItem setTag:i];
                    [songItem setTarget:self];
                } else {
                    break;
                }
            }
        }
    }
    return [upcomingSongsMenu autorelease];
}

- (NSMenu *)playlistsMenu
{
    NSMenu *playlistsMenu = [[NSMenu alloc] initWithTitle:@""];
    NSArray *playlists = [currentRemote playlists];
    NSMenuItem *tempItem;
    int i;
    
    for (i = 0; i < [playlists count]; i++) {
        tempItem = [playlistsMenu addItemWithTitle:[playlists objectAtIndex:i] action:@selector(performPlaylistMenuAction:) keyEquivalent:@""];
        [tempItem setTag:i + 1];
        [tempItem setTarget:self];
    }
    
    if (!_playingRadio && _currentPlaylist) {
        [[playlistsMenu itemAtIndex:_currentPlaylist - 1] setState:NSOnState];
    }
    return [playlistsMenu autorelease];
}

- (NSMenu *)eqMenu
{
    NSMenu *eqMenu = [[NSMenu alloc] initWithTitle:@""];
    NSArray *eqPresets = [currentRemote eqPresets];
    NSMenuItem *tempItem;
    int i;
    
    for (i = 0; i < [eqPresets count]; i++) {
        NSString *name;
	if ( ( name = [eqPresets objectAtIndex:i] ) ) {
            tempItem = [eqMenu addItemWithTitle:name action:@selector(performEqualizerMenuAction:) keyEquivalent:@""];
            [tempItem setTag:i];
            [tempItem setTarget:self];
	}
    }
    [[eqMenu itemAtIndex:([currentRemote currentEQPresetIndex] - 1)] setState:NSOnState];
    return [eqMenu autorelease];
}

- (void)performMainMenuAction:(id)sender
{
    switch ( [sender tag] )
    {
        case MTMenuPlayPauseItem:
            NSLog(@"MenuController: Play/Pause");
            [[MainController sharedController] playPause];
            //We're gonna have to change the Play menu item to Pause here too.
            break;
        case MTMenuFastForwardItem:
            NSLog(@"MenuController: Fast Forward");
            [[MainController sharedController] fastForward];
            //make sure play/pause item says sane through this
            break;
        case MTMenuRewindItem:
            NSLog(@"MenuController: Rewind");
            [[MainController sharedController] rewind];
            //make sure play/pause item says sane through this
            break;
        case MTMenuPreviousTrackItem:
            NSLog(@"MenuController: Previous Track");
            [[MainController sharedController] prevSong];
            break;
        case MTMenuNextTrackItem:
            NSLog(@"MenuController: Next Track");
            [[MainController sharedController] nextSong];
            break;
        case MTMenuShowPlayerItem:
            NSLog(@"MainController: Show Main Interface");
            [[MainController sharedController] showPlayer];
            break;
        case MTMenuPreferencesItem:
            NSLog(@"MenuController: Preferences...");
            [[MainController sharedController] showPreferences];
            break;
        case MTMenuQuitItem:
            NSLog(@"MenuController: Quit");
            [[MainController sharedController] quitMenuTunes];
            break;
        default:
            NSLog(@"MenuController: Unimplemented Menu Item OR Child-bearing Menu Item");
            break;
    }
}

- (void)performRatingMenuAction:(id)sender
{
    [[MainController sharedController] selectSongRating:[sender tag]];
}

- (void)performPlaylistMenuAction:(id)sender
{
    [[MainController sharedController] selectPlaylistAtIndex:[sender tag]];
}

- (void)performEqualizerMenuAction:(id)sender
{
    [[MainController sharedController] selectEQPresetAtIndex:[sender tag]];
}

- (void)performUpcomingSongsMenuAction:(id)sender
{
    [[MainController sharedController] selectSongAtIndex:[sender tag]];
}

- (void)updateMenu
{
    
    [_currentMenu update];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    return YES;
}

- (NSString *)systemUIColor
{
    NSDictionary *tmpDict;
    NSNumber *tmpNumber;
    if ( (tmpDict = [NSDictionary dictionaryWithContentsOfFile:[@"~/Library/Preferences/.GlobalPreferences.plist" stringByExpandingTildeInPath]]) ) {
        if ( (tmpNumber = [tmpDict objectForKey:@"AppleAquaColorVariant"]) ) {
            if ( ([tmpNumber intValue] == 1) ) {
                return @"Aqua";
            } else {
                return @"Graphite";
            }
        } else {
            return @"Aqua";
        }
    } else {
        return @"Aqua";
    }
}

- (void)setKeyEquivalentForCode:(short)code andModifiers:(long)modifiers
        onItem:(NSMenuItem *)item
{
    unichar charcode = 'a';
    int i;
    long cocoaModifiers = 0;
    static long carbonToCocoa[6][2] = 
    {
        { cmdKey, NSCommandKeyMask },
        { optionKey, NSAlternateKeyMask },
        { controlKey, NSControlKeyMask },
        { shiftKey, NSShiftKeyMask },
    };
    
    for (i = 0; i < 6; i++) {
        if (modifiers & carbonToCocoa[i][0]) {
            cocoaModifiers += carbonToCocoa[i][1];
        }
    }
    [item setKeyEquivalentModifierMask:cocoaModifiers];
    
    //Missing key combos for some keys. Must find them later.
    switch (code)
    {
        case 36:
            charcode = '\r';
        break;
        
        case 48:
            charcode = '\t';
        break;
        
        //Space -- ARGH!
        case 49:
        {
            // Haven't tested this, though it should work.
            // This doesn't work. :'(
            unichar buffer;
            [[NSString stringWithString:@"Space"] getCharacters:&buffer];
            charcode = buffer;
            /*MenuRef menuRef = _NSGetCarbonMenu([item menu]);
            NSLog(@"%@", menuRef);
            SetMenuItemCommandKey(menuRef, 0, NO, 49);
            SetMenuItemModifiers(menuRef, 0, kMenuNoCommandModifier);
            SetMenuItemKeyGlyph(menuRef, 0, kMenuBlankGlyph);
            charcode = 'b';*/
            
        }
        break;
        
        case 51:
            charcode = NSDeleteFunctionKey;
        break;
        
        case 53:
            charcode = '\e';
        break;
        
        case 71:
            charcode = '\e';
        break;
        
        case 76:
            charcode = '\r';
        break;
        
        case 96:
            charcode = NSF5FunctionKey;
        break;
        
        case 97:
            charcode = NSF6FunctionKey;
        break;
        
        case 98:
            charcode = NSF7FunctionKey;
        break;
        
        case 99:
            charcode = NSF3FunctionKey;
        break;
        
        case 100:
            charcode = NSF8FunctionKey;
        break;
        
        case 101:
            charcode = NSF9FunctionKey;
        break;
        
        case 103:
            charcode = NSF11FunctionKey;
        break;
        
        case 105:
            charcode = NSF3FunctionKey;
        break;
        
        case 107:
            charcode = NSF14FunctionKey;
        break;
        
        case 109:
            charcode = NSF10FunctionKey;
        break;
        
        case 111:
            charcode = NSF12FunctionKey;
        break;
        
        case 113:
            charcode = NSF13FunctionKey;
        break;
        
        case 114:
            charcode = NSInsertFunctionKey;
        break;
        
        case 115:
            charcode = NSHomeFunctionKey;
        break;
        
        case 116:
            charcode = NSPageUpFunctionKey;
        break;
        
        case 117:
            charcode = NSDeleteFunctionKey;
        break;
        
        case 118:
            charcode = NSF4FunctionKey;
        break;
        
        case 119:
            charcode = NSEndFunctionKey;
        break;
        
        case 120:
            charcode = NSF2FunctionKey;
        break;
        
        case 121:
            charcode = NSPageDownFunctionKey;
        break;
        
        case 122:
            charcode = NSF1FunctionKey;
        break;
        
        case 123:
            charcode = NSLeftArrowFunctionKey;
        break;
        
        case 124:
            charcode = NSRightArrowFunctionKey;
        break;
        
        case 125:
            charcode = NSDownArrowFunctionKey;
        break;
        
        case 126:
            charcode = NSUpArrowFunctionKey;
        break;
    }
    
    if (charcode == 'a') {
        unsigned long state;
        long keyTrans;
        char charCode;
        Ptr kchr;
        state = 0;
        kchr = (Ptr) GetScriptVariable(smCurrentScript, smKCHRCache);
        keyTrans = KeyTranslate(kchr, code, &state);
        charCode = keyTrans;
        [item setKeyEquivalent:[NSString stringWithCString:&charCode length:1]];
    } else if (charcode != 'b') {
        [item setKeyEquivalent:[NSString stringWithCharacters:&charcode length:1]];
    }
}

@end
