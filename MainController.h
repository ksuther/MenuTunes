/*
 *	MenuTunes
 *  MainController
 *    App Controller Class
 *
 *  Original Author : Matthew Judy <mjudy@ithinksw.com>
 *   Responsibility : Matthew Judy <mjudy@ithinksw.com>
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


@class StatusWindowController;


@interface MainController : NSObject
{
    ITStatusItem   *statusItem;
    NSMutableArray *remoteArray;
    ITMTRemote     *currentRemote;

    ITMTRemotePlayerRunningState  playerRunningState;
    ITMTRemotePlayerPlaylistClass latestPlaylistClass;
    
    //Used in updating the menu automatically
    NSTimer *refreshTimer;

    NSString *_latestSongIdentifier;

    StatusWindowController *statusWindowController; //Shows track info and upcoming songs.
    NSUserDefaults *df;
}


- (ITMTRemote *)currentRemote;
- (void)clearHotKeys;
- (void)closePreferences;

@end