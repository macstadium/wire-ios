// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "AudioTrackViewController.h"
#import "AudioTrackViewController+Internal.h"
#import "AudioTrackPlayer.h"
#import "SoundcloudAudioTrack.h"

#import "Wire-Swift.h"
#import "WireSyncEngine+iOS.h"
#import "LinkAttachmentCache.h"
#import "SoundcloudService.h"

@import WireLinkPreview;

static NSString* ZMLogTag ZM_UNUSED = @"UI";


@import AVFoundation;

@interface AudioTrackViewController ()

@property (nonatomic, readonly) AudioTrackPlayer *audioTrackPlayer;
@property (nonatomic, readonly) BOOL isTrackPlayingInAudioPlayer;

@property (nonatomic) NSObject *artworkObserver;
@property (nonatomic) NSObject *audioPlayerProgressObserver;
@property (nonatomic) NSObject *audioPlayerStateObserver;

@end

@implementation AudioTrackViewController

@synthesize linkAttachment;

- (void)dealloc
{
    self.artworkObserver = nil;
}

- (instancetype)initWithAudioTrackPlayer:(AudioTrackPlayer *)audioTrackPlayer
{
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        _audioTrackPlayer = audioTrackPlayer;
    }
    
    return self;
}

- (instancetype)init
{
    self = [self initWithAudioTrackPlayer:[AppDelegate sharedAppDelegate].mediaPlaybackManager.audioTrackPlayer];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.view.preservesSuperviewLayoutMargins = YES;
    
    _backgroundView = [[UIImageView alloc] init];
    self.backgroundView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundView.accessibilityIdentifier = @"BackgroundView";
    self.backgroundView.clipsToBounds = YES;
    [self.view addSubview:self.backgroundView];
    
    _blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    self.blurEffectView.preservesSuperviewLayoutMargins = YES;
    self.blurEffectView.contentView.preservesSuperviewLayoutMargins = YES;
    self.blurEffectView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.blurEffectView];
    
    _audioTrackView = [[AudioTrackView alloc] init];
    [self.blurEffectView.contentView addSubview:self.audioTrackView];
    
    _audioHeaderView = [[AudioHeaderView alloc] init];
    self.audioHeaderView.preservesSuperviewLayoutMargins = YES;
    [self.blurEffectView.contentView addSubview:self.audioHeaderView];
    
    _subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.textColor = [UIColor wr_colorFromColorScheme:ColorSchemeColorTextForeground variant:ColorSchemeVariantDark];
    self.subtitleLabel.font = UIFont.smallRegularFont;
    [self.blurEffectView.contentView addSubview:self.subtitleLabel];
    
    [self.audioTrackView.playPauseButton addTarget:self action:@selector(playPause:) forControlEvents:UIControlEventTouchUpInside];
    [self.audioHeaderView.providerButton addTarget:self action:@selector(openInBrowser:) forControlEvents:UIControlEventTouchUpInside];
    
    [self createInitialConstraints];
    [self updateViews];
    
    self.audioPlayerProgressObserver = [KeyValueObserver observeObject:self.audioTrackPlayer
                                                               keyPath:NSStringFromSelector(@selector(progress))
                                                                target:self selector:@selector(audioProgressChanged:)
                                                               options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew];
    
    self.audioPlayerStateObserver = [KeyValueObserver observeObject:self.audioTrackPlayer
                                                            keyPath:NSStringFromSelector(@selector(state))
                                                             target:self selector:@selector(audioPlayerStateChanged:)
                                                            options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew];
}

- (void)tearDown;
{
    [self.audioTrackPlayer stop];
}

- (UIView *)touchableView
{
    return self.view;
}

- (void)fetchAttachment
{
    LinkAttachmentCache *cache = [LinkAttachmentCache sharedInstance];
    id cachedResource = [cache objectForKey:self.linkAttachment.permalink];
    
    if (cachedResource != nil) {
        self.audioTrack = cachedResource;
    } else {
        ZM_WEAK(self);
        [[SoundcloudService sharedInstance] loadAudioResourceFromURL:self.linkAttachment.permalink completion:^(id audioResource, NSError *error) {
            ZM_STRONG(self);
            if (error == nil && audioResource != nil) {
                self.audioTrack = audioResource;
                [cache setObject:audioResource forKey:self.linkAttachment.permalink];
            }
            else {
                self.audioTrack = nil;
            }
        }];
    }
}

- (void)setAudioTrack:(id<AudioTrack>)audioTrack
{
    _audioTrack = audioTrack;
    
    [self updateViews];
    
    if (self.audioTrack.failedToLoad || self.audioTrack == nil) {
        self.view.backgroundColor = UIColor.blackColor;
        self.audioTrackView.failedToLoad = YES;
    }
    else {
        self.view.backgroundColor = UIColor.soundcloudOrange;
        self.audioTrackView.failedToLoad = NO;
    }
    [self updateSubtitle];
    [self updateIsPlayingIcon];

    if (self.audioTrack.artwork == nil) {
        [self.audioTrack fetchArtwork];
    }
}

- (void)setProviderImage:(UIImage *)providerImage
{
    _providerImage = providerImage;
    [self.audioHeaderView.providerButton setImage:providerImage forState:UIControlStateNormal];
}

- (void)updateViews
{
    [self.audioHeaderView.providerButton setImage:self.providerImage forState:UIControlStateNormal];
    self.audioHeaderView.artistLabel.text = [self.audioTrack.author uppercasedWithCurrentLocale];
    self.audioHeaderView.trackTitleLabel.text = [self.audioTrack.title uppercasedWithCurrentLocale];
    
    self.artworkObserver = [KeyValueObserver observeObject:self.audioTrack
                                                   keyPath:NSStringFromSelector(@selector(artwork))
                                                    target:self
                                                  selector:@selector(artworkChanged:)
                                                   options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew];
}

- (void)updateSubtitle
{
    if (self.audioTrack.failedToLoad || self.audioTrack == nil) {
        self.subtitleLabel.text = NSLocalizedString(@"content.player.unable_to_play", @"");
    }
    else {
        self.subtitleLabel.text = @"";
    }
}

- (void)updateIsPlayingIcon
{
    if (self.isTrackPlayingInAudioPlayer) {
        ZetaIconType icon = self.audioTrackPlayer.isPlaying ? ZetaIconTypeMediaBarPause : ZetaIconTypeMediaBarPlay;
        [self.audioTrackView.playPauseButton setIcon:icon withSize:ZetaIconSizeLarge forState:UIControlStateNormal];
    }
}

- (BOOL)isTrackPlayingInAudioPlayer
{
    return [self.audioTrackPlayer.sourceMessage isEqual:self.sourceMessage] && [self.audioTrackPlayer.audioTrack isEqual:self.audioTrack];
}

#pragma mark - Actions

- (IBAction)playPause:(id)sender
{
    if (self.audioTrackPlayer.sourceMessage != self.sourceMessage) {
        ZM_WEAK(self);
        [self.audioTrackPlayer loadTrack:self.audioTrack sourceMessage:self.sourceMessage completionHandler:^(BOOL loaded, NSError *error) {
            ZM_STRONG(self);
            if (loaded) {
                [self.audioTrackPlayer play];
            } else {
                ZMLogWarn(@"Couldn't load audio track (%@): %@", self.audioTrack.title, error);
            }
        }];
    } else {
        if (self.audioTrackPlayer.isPlaying) {
            [self.audioTrackPlayer pause];
        } else {
            [self.audioTrackPlayer play];
        }
    }
}

- (IBAction)openInBrowser:(id)sender
{
    [[UIApplication sharedApplication] openURL:self.audioTrack.externalURL
                                       options:@{}
                             completionHandler:NULL];
}

#pragma mark - KVO observer

- (void)audioPlayerStateChanged:(NSDictionary *)change
{
    if (self.isTrackPlayingInAudioPlayer) {
        [self updateIsPlayingIcon];
        [self updateSubtitle];
        self.audioTrackView.failedToLoad = self.audioTrackPlayer.audioTrack.failedToLoad || self.audioTrack == nil;
        self.audioTrackView.progress = self.audioTrackPlayer.progress;
    } else {
        [self.audioTrackView.playPauseButton setIcon:ZetaIconTypePlay withSize:ZetaIconSizeLarge forState:UIControlStateNormal];
        self.audioTrackView.progress = 0;
    }
}

- (void)audioProgressChanged:(NSDictionary *)dictionary
{
    if (self.isTrackPlayingInAudioPlayer) {
        [self.audioTrackView setProgress:self.audioTrackPlayer.progress duration:1.0/60.0];
    }
}

- (void)artworkChanged:(NSDictionary *)change
{
    self.audioTrackView.artworkImageView.image = self.audioTrack.artwork;
    self.backgroundView.image = self.audioTrack.artwork;
}

@end
