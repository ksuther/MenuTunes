/*
 *	MenuTunes
 *	iTunesRemote.h
 *
 *	Copyright (c) 2003 iThink Software
 *
 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ITMTRemote/ITMTRemote.h>
#import <ITFoundation/ITFoundation.h>
#import <ITMac/ITMac.h>

@class PlaylistNode;

@interface iTunesRemote : ITMTRemote <ITMTRemote>
{
    ProcessSerialNumber savedPSN;
	float _iTunesVersion;
}
- (BOOL)isPlaying;
- (ProcessSerialNumber)iTunesPSN;
- (ProcessSerialNumber)SpotifyPSN;
- (NSString*)formatTimeInSeconds:(long)seconds;
- (NSString*)zeroSixty:(int)seconds;
@end
