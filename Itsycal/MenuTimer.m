//
//  MenuTimer.m
//  Itsycal
//
//  Created by Sanjay Madan on 11/4/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "MenuTimer.h"
#import "Itsycal.h"
#import "MoUtils.h"

// The longest timer, in minutes, and where the slider starts
// before any timer has run.
static const NSInteger kMaxMinutes = 60;
static const NSInteger kDefaultMinutes = 10;

// Layout of the slider's menu item view. The width is a minimum:
// the view widens with the menu.
static const CGFloat kSliderViewWidth = 200;
static const CGFloat kSliderViewHeight = 28;
static const CGFloat kSliderViewInset = 14;  // left and right

// How late the end timer can fire and still ring. It's normally on
// time (see _activity), so this only allows for small delays. Later
// than this (the Mac was asleep at the end time), the timer ends
// without ringing. A timer that ended while Itsycal wasn't running
// never rings; see -init.
static const NSTimeInterval kLateAlarmGrace = 10;

@implementation MenuTimer
{
    // When the timer ends, in MonotonicClockTime(), if _running. That
    // clock isn't changed by setting the time, and it keeps counting
    // while the Mac sleeps. Its zero point changes when the Mac
    // restarts, so the end is also saved as a date (in kTimerEndDate)
    // to resume the timer after a relaunch.
    NSTimeInterval _deadline;
    BOOL _running;
    NSTimer *_endTimer;         // fires at _deadline
    NSTimer *_ticker;           // updates _cancelItem while the menu is open
    NSMenuItem *_cancelItem;    // "Cancel: m:ss" while its menu is open
    NSMenuItem *_startItem;     // "Start: 12 min" while its menu is open
    NSDateComponentsFormatter *_durationFormatter;
    NSDictionary *_titleAttributes;
    id<NSObject> _activity;     // keeps idle sleep and App Nap from delaying _endTimer
    NSSound *_sound;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Resume a timer saved before Itsycal quit. If it ended while
        // Itsycal wasn't running, drop it without ringing. If the saved
        // end is more than the longest timer away (the date is bad),
        // bring it in to that, so the timer, and keeping the Mac awake
        // for it, can't go on for hours.
        id endDate = [NSUserDefaults.standardUserDefaults objectForKey:kTimerEndDate];
        NSTimeInterval remaining = [endDate isKindOfClass:[NSDate class]] ? [endDate timeIntervalSinceNow] : 0;
        if (remaining > 0) {
            [self runFor:MIN(remaining, kMaxMinutes * 60)];
        }
        else {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:kTimerEndDate];
        }
        // _endTimer doesn't count time asleep, so check again after the
        // Mac wakes. Use the main queue: this touches timers and the
        // open menu. MenuTimer lasts as long as the app, so the observer
        // is never removed and its token isn't kept.
        __weak typeof(self) weakSelf = self;
        [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            [weakSelf scheduleEndTimer];
        }];
        // A clock change doesn't affect the timer, but the saved end
        // date is clock time, so save it again for a relaunch.
        [NSNotificationCenter.defaultCenter addObserverForName:NSSystemClockDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            [weakSelf saveEndDate];
        }];
    }
    return self;
}

#pragma mark -
#pragma mark Timer

// Time left until _deadline; negative once it has passed.
- (NSTimeInterval)timeRemaining
{
    return _deadline - MonotonicClockTime();
}

- (void)startWithMinutes:(NSInteger)minutes
{
    [self stopAlarm];
    [NSUserDefaults.standardUserDefaults setInteger:minutes forKey:kTimerRecentMinutes];
    [self runFor:minutes * 60];
}

// Run the timer for the given seconds, for a new timer or one resumed
// at launch.
- (void)runFor:(NSTimeInterval)duration
{
    _deadline = MonotonicClockTime() + duration;
    _running = YES;
    [self saveEndDate];
    [self scheduleEndTimer];
}

// Save when the running timer ends, as clock time, to resume it
// after a relaunch.
- (void)saveEndDate
{
    if (!_running) return;
    NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:[self timeRemaining]];
    [NSUserDefaults.standardUserDefaults setObject:endDate forKey:kTimerEndDate];
}

- (void)clearTimer
{
    _running = NO;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kTimerEndDate];
    [_endTimer invalidate];
    _endTimer = nil;
    [self endActivity];
}

- (void)endActivity
{
    if (_activity) {
        [NSProcessInfo.processInfo endActivity:_activity];
        _activity = nil;
    }
}

// If the running timer is at 0:00, end it and return YES. This is the
// one place that decides the timer has ended, whether _endTimer, the
// ticker or opening the menu notices first. _endTimer can be late or a
// little early: it doesn't count time asleep, as _deadline does.
- (BOOL)endIfDue
{
    if (!_running || [self secondsRemaining] > 0) return NO;
    [self timerEndedLateBy:MAX(0, -[self timeRemaining])];
    return YES;
}

// Schedule _endTimer for _deadline, or end the timer if it's due.
// Safe to call any time; it starts over each call. When no timer is
// running, -clearTimer has already stopped _endTimer and _activity.
- (void)scheduleEndTimer
{
    if (!_running || [self endIfDue]) return;

    [_endTimer invalidate];

    NSTimeInterval remaining = [self timeRemaining];
    _endTimer = [NSTimer timerWithTimeInterval:remaining target:self selector:@selector(endTimerFired:) userInfo:nil repeats:NO];
    _endTimer.tolerance = 0;
    [NSRunLoop.mainRunLoop addTimer:_endTimer forMode:NSRunLoopCommonModes];

    if (!_activity) {
        // Keep the Mac from idle sleeping, which would end the timer
        // without ringing, and keep App Nap from delaying _endTimer.
        // The display can still sleep, and closing the lid still
        // sleeps the Mac.
        _activity = [NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiated reason:@"Countdown timer"];
    }
}

- (void)endTimerFired:(NSTimer *)timer
{
    // Ends the timer, or reschedules if this fired a little early.
    [self scheduleEndTimer];
}

- (void)timerEndedLateBy:(NSTimeInterval)late
{
    [self clearTimer];
    if (late <= kLateAlarmGrace) {
        [self ringAlarm];
    }

    // If the menu is open, swap "Cancel" for the slider
    // and "Start".
    NSMenuItem *cancelItem = _cancelItem;
    [self forgetMenu];
    NSMenu *menu = cancelItem.menu;
    if (menu) {
        NSInteger index = [menu indexOfItem:cancelItem];
        [menu removeItemAtIndex:index];
        for (NSMenuItem *item in [self startItems]) {
            [menu insertItem:item atIndex:index++];
        }
    }
}

#pragma mark -
#pragma mark Alarm

- (void)ringAlarm
{
    [self stopAlarm];
    _sound = [NSSound soundNamed:@"alarm"];  // Sounds/alarm.m4a
    [_sound play];
}

- (void)stopAlarm
{
    [_sound stop];
    _sound = nil;
}

#pragma mark -
#pragma mark Menu

- (NSArray<NSMenuItem *> *)menuItems
{
    [self forgetMenu];

    // Don't offer to cancel a timer that's at 0:00.
    [self endIfDue];

    NSMenuItem *header = [NSMenuItem sectionHeaderWithTitle:NSLocalizedString(@"Timer", @"Menu section header for the countdown timer")];

    if (!_running) {
        return [@[header] arrayByAddingObjectsFromArray:[self startItems]];
    }

    _cancelItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(cancelTimer:) keyEquivalent:@""];
    _cancelItem.preferredImageVisibility = NSMenuItemImageVisibilityHidden;
    [self setTitle:[self cancelTitle] ofItem:_cancelItem];
    _cancelItem.target = self;

    // Update the title each time the displayed seconds change, which
    // is on whole seconds before _deadline.
    NSTimeInterval untilNextSecond = [self timeRemaining] - ([self secondsRemaining] - 1);
    NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:untilNextSecond];
    _ticker = [[NSTimer alloc] initWithFireDate:fireDate interval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    _ticker.tolerance = 0;
    [NSRunLoop.mainRunLoop addTimer:_ticker forMode:NSRunLoopCommonModes];

    return @[header, _cancelItem];
}

- (void)menuDidClose
{
    [self forgetMenu];
}

// Stop the countdown and drop the items of a menu that closed or
// whose items are being replaced.
- (void)forgetMenu
{
    [_ticker invalidate];
    _ticker = nil;
    _cancelItem = nil;
    _startItem = nil;
}

// Round up so a 10-minute timer starts at 10:00 and the
// last second shows 0:01.
- (NSInteger)secondsRemaining
{
    // The ticker fires right on whole seconds before _deadline, where
    // a tiny timing error could make ceil() round up to the previous
    // second. Subtracting a little first keeps errors under 50 ms
    // from showing a second twice.
    return MAX(0, (NSInteger)ceil([self timeRemaining] - 0.05));
}

- (void)tick:(NSTimer *)timer
{
    // At 0:00, end the timer, which swaps "Cancel" for the slider.
    if ([self endIfDue]) return;
    [self setTitle:[self cancelTitle] ofItem:_cancelItem];
}

- (NSString *)cancelTitle
{
    NSInteger remaining = [self secondsRemaining];
    NSString *time = [NSString stringWithFormat:@"%ld:%02ld", remaining / 60, remaining % 60];
    return [NSString stringWithFormat:NSLocalizedString(@"Cancel: %@", @"Timer menu item; %@ is the time left, like 7:42"), time];
}

// A slider for choosing minutes and "Start: 12 min", which
// starts the timer. The slider starts at the last timer's minutes.
- (NSArray<NSMenuItem *> *)startItems
{
    NSInteger minutes = [NSUserDefaults.standardUserDefaults integerForKey:kTimerRecentMinutes];
    if (minutes < 1 || minutes > kMaxMinutes) {
        minutes = kDefaultMinutes;
    }

    // The slider goes from 0 so its tick marks fall on multiples
    // of 10. A value of 0 counts as 1 minute.
    NSSlider *slider = [NSSlider sliderWithValue:minutes minValue:0 maxValue:kMaxMinutes target:self action:@selector(sliderChanged:)];
    slider.numberOfTickMarks = kMaxMinutes / 10 + 1;
    slider.continuous = YES;
    slider.controlSize = NSControlSizeSmall;
    // Otherwise the filled part of the track is the accent color when
    // Itsycal is the active app and gray when it isn't, which varies
    // with what was clicked last. Make it always gray.
    slider.tintProminence = NSTintProminenceNone;
    slider.accessibilityLabel = NSLocalizedString(@"Timer Duration", @"Accessibility label for the timer's minutes slider");

    // Width-sizable so the menu widens the view, and the slider
    // with it, when the menu is wider than the view.
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kSliderViewWidth, kSliderViewHeight)];
    view.autoresizingMask = NSViewWidthSizable;
    [slider sizeToFit];
    CGFloat sliderHeight = NSHeight(slider.frame);
    slider.frame = NSMakeRect(kSliderViewInset, floor((kSliderViewHeight - sliderHeight) / 2), kSliderViewWidth - 2 * kSliderViewInset, sliderHeight);
    slider.autoresizingMask = NSViewWidthSizable;
    [view addSubview:slider];

    NSMenuItem *sliderItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    sliderItem.view = view;

    // -updateForSlider:minutes: sets the title and tag.
    _startItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(startTimer:) keyEquivalent:@""];
    // Like the rest of the context menu (see -statusItemContextMenu),
    // never show an image, which the system may add for "Start" or
    // "Cancel". Set here too because these items can be put in the
    // open menu when a timer ends.
    _startItem.preferredImageVisibility = NSMenuItemImageVisibilityHidden;
    _startItem.target = self;
    [self updateForSlider:slider minutes:minutes];

    return @[sliderItem, _startItem];
}

- (void)sliderChanged:(NSSlider *)slider
{
    NSInteger minutes = MAX(1, lround(slider.doubleValue));
    slider.integerValue = minutes;  // snap to whole minutes while dragging
    [self updateForSlider:slider minutes:minutes];
}

- (void)updateForSlider:(NSSlider *)slider minutes:(NSInteger)minutes
{
    [self setTitle:[self startTitle:minutes] ofItem:_startItem];
    _startItem.tag = minutes;
    // VoiceOver reads this instead of the raw value, so it says the
    // minutes the timer will use, not 0 for the slider's left end.
    slider.accessibilityValueDescription = [self durationString:minutes];
}

- (NSString *)startTitle:(NSInteger)minutes
{
    return [NSString stringWithFormat:NSLocalizedString(@"Start: %@", @"Timer menu item; %@ is a duration, like 12 min"), [self durationString:minutes]];
}

// Titles use the menu font with monospaced digits so the countdown
// doesn't shift as it changes, and "Start" doesn't as the
// slider moves. The plain title is set too, for accessibility and
// type-to-select.
- (void)setTitle:(NSString *)title ofItem:(NSMenuItem *)item
{
    item.title = title;
    item.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:[self titleAttributes]];
}

- (NSDictionary *)titleAttributes
{
    if (!_titleAttributes) {
        // Like -[ViewController updateStatusItemFont], modify the font
        // with a font descriptor instead of using
        // +monospacedDigitSystemFontOfSize:weight:.
        NSFont *font = [NSFont menuFontOfSize:0];
        NSFontDescriptor *desc = [font.fontDescriptor fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute: @[@{NSFontFeatureTypeIdentifierKey: @(kNumberSpacingType), NSFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}]}];
        _titleAttributes = @{NSFontAttributeName: [NSFont fontWithDescriptor:desc size:0]};
    }
    return _titleAttributes;
}

- (NSString *)durationString:(NSInteger)minutes
{
    if (!_durationFormatter) {
        _durationFormatter = [NSDateComponentsFormatter new];
        _durationFormatter.allowedUnits = NSCalendarUnitMinute;
        _durationFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
    }
    return [_durationFormatter stringFromTimeInterval:minutes * 60];
}

- (void)startTimer:(NSMenuItem *)sender
{
    [self startWithMinutes:sender.tag];
}

- (void)cancelTimer:(NSMenuItem *)sender
{
    [self clearTimer];
}

@end
