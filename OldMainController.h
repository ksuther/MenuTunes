/*
 *	MenuTunes
 *  MainController
 *    App Controller Class
 *
 *  Original Author : Kent Sutherland <ksuther@ithinksw.com>
 *   Responsibility : Kent Sutherland <ksuther@ithinksw.com>
 *
 *  Copyright (c) 2002-2003 iThink Software.
 *  All Rights Reserved
 *
 */


#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ITKit/ITKit.h>
#import <ITFoundation/ITFoundation.h>
#import <ITMTRemote/ITMTRemote.h>
#import <StatusWindow.h>

//@class MenuTunesView;
@class PreferencesController, StatusWindow;

@interface MainController : NSObject
{
    ITStatusItem   *statusItem;
    NSMenu         *menu;
    ITMTRemote     *currentRemote;
    NSMutableArray *remoteArray;
    
    //Used in updating the menu automatically
    NSTimer *refreshTimer;
    int      trackInfoIndex;
    int      lastSongIndex;
    int      lastPlaylistIndex;
    BOOL     isPlayingRadio;
    
    ITMTRemotePlayerRunningState isAppRunning;
    BOOL didHaveAlbumName;
    BOOL didHaveArtistName; //Helper variable for creating the menu
    
    //For upcoming songs
    NSMenuItem *upcomingSongsItem;
    NSMenu     *upcomingSongsMenu;
    
    //For playlist selection
    NSMenuItem *playlistItem;
    NSMenu     *playlistMenu;
    
    //For EQ sets
    NSMenuItem *eqItem;
    NSMenu     *eqMenu;
    
    //For song ratings
    NSMenuItem *songRatingMenuItem;
    NSMenu *ratingMenu;
    
    NSMenuItem *playPauseMenuItem; //Toggle between 'Play' and 'Pause'
    
    PreferencesController *prefsController;
    StatusWindow *statusWindow; //Shows track info and upcoming songs.
}

- (void)applicationLaunched:(NSNotification *)note;
- (void)applicationTerminated:(NSNotification *)note;

- (void)registerDefaults;
- (void)rebuildMenu;

- (void)clearHotKeys;
- (void)closePreferences;

@end