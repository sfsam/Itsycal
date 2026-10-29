//
//  Created by Sanjay Madan on 10/28/26.
//  Copyright © 2026 mowglii.com. All rights reserved.
//

#import "AgendaPopoverVC.h"
#import "EventCenter.h"
#import "MoThemeView.h"
#import "MoUtils.h"
#import "MoVFLHelper.h"
#import "Sizer.h"
#import "Themer.h"

// The width of the popover's text.
static const CGFloat kTextWidth = 280;

// Rows for many attendees take long to lay out: about 40 ms for 50,
// seconds for 500. Show at most this many lines: all the attendees if
// they fit, or one fewer and a line saying how many more.
static const NSUInteger kMaxAttendeeLines = 50;

// Space between the popover's edge and its sections, between
// sections, and between a section's edge and its rows.
static const CGFloat kInset = 10;

// The popover is at most this tall, about as tall as Calendar's event
// popover can be, and the body scrolls. (NSPopover keeps it on screen.)
static const CGFloat kMaxPopoverHeight = 800;

// YES if any of views isn't hidden.
static BOOL AnyViewShows(NSArray<NSView *> *views)
{
    for (NSView *view in views) {
        if (!view.hidden) return YES;
    }
    return NO;
}

// A dot in a calendar's color, the size of the agenda's. Gray if the
// calendar has no color.
static NSImage *CalendarDotImage(NSColor *color)
{
    CGFloat side = SizePref.agendaDotWidth;
    return [NSImage imageWithSize:NSMakeSize(side, side) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [(color ?: NSColor.secondaryLabelColor) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
        return YES;
    }];
}

#pragma mark -
#pragma mark AgendaPopoverSection

// =========================================================================
// AgendaPopoverSection
// =========================================================================

// A section of the popover, like those of Calendar's event popover:
// rows on a rounded, filled background. -updateHidden hides it when
// all its rows are hidden.
@interface AgendaPopoverSection : NSStackView
- (instancetype)initWithRows:(NSArray<NSView *> *)rows;
- (void)updateHidden;
// Set the width of the section's rows. kTextWidth to start.
- (void)setRowWidth:(CGFloat)rowWidth;
// If set, the section's corners are concentric with the popover's
// corners, and this is called with the radius they resolve to.
@property (nonatomic, copy) void (^concentricRadiusChanged)(CGFloat radius);
@end

@implementation AgendaPopoverSection
{
    NSArray<NSView *> *_rows;
    NSArray<NSLayoutConstraint *> *_rowWidths;
}

- (instancetype)initWithRows:(NSArray<NSView *> *)rows
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _rows = rows;
        self.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.alignment = NSLayoutAttributeLeading;
        self.edgeInsets = NSEdgeInsetsMake(kInset, kInset, kInset, kInset);
        self.wantsLayer = YES;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        NSMutableArray *rowWidths = [NSMutableArray new];
        for (NSView *row in rows) {
            [self addArrangedSubview:row];
            NSLayoutConstraint *rowWidth = [row.widthAnchor constraintEqualToConstant:kTextWidth];
            rowWidth.active = YES;
            [rowWidths addObject:rowWidth];
        }
        _rowWidths = rowWidths;
    }
    return self;
}

- (void)updateHidden
{
    self.hidden = !AnyViewShows(_rows);
}

- (void)setRowWidth:(CGFloat)rowWidth
{
    for (NSLayoutConstraint *constraint in _rowWidths) {
        constraint.constant = rowWidth;
    }
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    self.layer.backgroundColor = Theme.popoverSectionColor.CGColor;
}

- (NSViewCornerConfiguration *)cornerConfiguration
{
    if (self.concentricRadiusChanged == nil) return [super cornerConfiguration];
    // One radius for all four corners: the largest they resolve to.
    return [NSViewCornerConfiguration configurationWithUniformRadius:NSViewCornerRadius.containerConcentricRadius];
}

- (void)viewDidChangeEffectiveCornerRadii
{
    [super viewDidChangeEffectiveCornerRadii];
    if (self.concentricRadiusChanged) {
        self.concentricRadiusChanged(self.effectiveCornerRadii.topLeft);
    }
}

@end

#pragma mark -
#pragma mark AgendaPopoverTextView

// =========================================================================
// AgendaPopoverTextView
// =========================================================================

// Selectable text with links, as tall as its text. It uses TextKit 1
// from the start. (A plain NSTextView starts with TextKit 2 and
// switches to TextKit 1 the first time its layoutManager is used.)
@interface AgendaPopoverTextView : NSTextView
// Set the width the text wraps to. kTextWidth to start.
- (void)setWrapWidth:(CGFloat)width;
- (void)setAttributedText:(NSAttributedString *)text;
@end

@implementation AgendaPopoverTextView

- (instancetype)init
{
    self = [super initUsingTextLayoutManager:NO];
    if (self) {
        self.editable = NO;
        self.selectable = YES;
        self.drawsBackground = NO;
        // Auto Layout sizes the view, from -intrinsicContentSize.
        self.verticallyResizable = NO;
        self.horizontallyResizable = NO;
        self.textContainer.widthTracksTextView = NO;
        self.textContainer.lineFragmentPadding = 0;
        [self setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
        [self setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
        [self setWrapWidth:kTextWidth];
    }
    return self;
}

- (void)setWrapWidth:(CGFloat)width
{
    self.textContainer.size = NSMakeSize(width, CGFLOAT_MAX);
    [self invalidateIntrinsicContentSize];
}

- (void)setAttributedText:(NSAttributedString *)text
{
    [self.textStorage setAttributedString:text];
    [self invalidateIntrinsicContentSize];
}

- (NSSize)intrinsicContentSize
{
    [self.layoutManager ensureLayoutForTextContainer:self.textContainer];
    CGFloat height = NSHeight([self.layoutManager usedRectForTextContainer:self.textContainer]);
    return NSMakeSize(NSViewNoIntrinsicMetric, height);
}

@end

#pragma mark -
#pragma mark AgendaPopoverVC

// =========================================================================
// AgendaPopoverVC
// =========================================================================

@implementation AgendaPopoverVC
{
    NSStackView *_header; // pinned at the top
    NSStackView *_body;   // scrolls below the header
    NSArray<AgendaPopoverSection *> *_sections;
    AgendaPopoverSection *_titleSection; // its corners set the others'
    NSTextField *_title;
    NSButton *_btnDelete;
    NSTextField *_duration;
    NSTextField *_recurrence;
    AgendaPopoverTextView *_location;
    AgendaPopoverTextView *_note;
    AgendaPopoverTextView *_URL;
    NSStackView *_attendees;
    NSStackView *_meetingRow;  // video icon, host and Join button
    NSImageView *_meetingIcon;
    NSTextField *_meetingHost;
    NSURL *_meetingURL;
    NSStackView *_calendarRow; // the calendar's dot and name
    NSImageView *_calendarDot;
    NSTextField *_calendarName;
    NSScrollView *_scrollView;
    NSDataDetector *_linkDetector;
    NSRegularExpression *_hiddenLinksRegex;
    NSRegularExpression *_messageLinksRegex;
    NSRegularExpression *_htmlTagRegex;
}

- (instancetype)init
{
    // Convenience functions.
    NSTextField* (^label)(void) = ^NSTextField* {
        NSTextField *lbl = [NSTextField wrappingLabelWithString:@""];
        lbl.drawsBackground = NO;
        lbl.textColor = Theme.currentMonthTextColor;
        [lbl setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        return lbl;
    };
    self = [super init];
    if (self) {
        _title = label();
        _duration = label();
        _recurrence = label();
        // The title is pinned above the scroll view, so a very long one
        // could push everything else out of the popover. Cap it.
        _title.maximumNumberOfLines = 5;
        _title.cell.truncatesLastVisibleLine = YES;
        
        _location = [AgendaPopoverTextView new];
        _note = [AgendaPopoverTextView new];
        _URL = [AgendaPopoverTextView new];
        
        _btnDelete = [NSButton new];
        _btnDelete.image = [NSImage imageWithSystemSymbolName:@"delete.backward" accessibilityDescription:NSLocalizedString(@"Delete This Event", @"")];
        _btnDelete.imagePosition = NSImageOnly;
        _btnDelete.title = @"";
        _btnDelete.focusRingType = NSFocusRingTypeNone;
        _btnDelete.bordered = NO;
        _btnDelete.contentTintColor = NSColor.secondaryLabelColor;
        _btnDelete.target = self;
        _btnDelete.action = @selector(deleteClicked:);
        unichar backspaceKey = NSBackspaceCharacter;
        _btnDelete.keyEquivalent = [NSString stringWithCharacters:&backspaceKey length:1];
        
        NSView *titleHolder = [NSView new];
        [titleHolder addSubview:_title];
        [titleHolder addSubview:_btnDelete];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:titleHolder metrics:nil views:NSDictionaryOfVariableBindings(_title, _btnDelete)];
        [vfl :@"H:|[_title]-(>=10)-[_btnDelete]|" :NSLayoutFormatAlignAllCenterY];
        [vfl :@"V:|[_title]|"];

        _attendees = [NSStackView new];
        _attendees.orientation = NSUserInterfaceLayoutOrientationVertical;
        _attendees.alignment = NSLayoutAttributeLeft;
        _attendees.spacing = 4;
        _attendees.detachesHiddenViews = NO;
        [_attendees setClippingResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];

        // A video meeting (Zoom, Teams, etc.): an icon, the meeting's
        // host and a button to join it, like Calendar.
        _meetingIcon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"video" accessibilityDescription:nil]];
        _meetingIcon.accessibilityElement = NO;
        _meetingIcon.contentTintColor = Theme.agendaEventTextColor;
        _meetingHost = [NSTextField labelWithString:@""];
        _meetingHost.lineBreakMode = NSLineBreakByTruncatingTail;
        [_meetingHost setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSButton *joinButton = [NSButton buttonWithTitle:NSLocalizedString(@"Join", @"Button in the event popover that joins the event's video meeting (Zoom, Teams, etc.)") target:self action:@selector(joinMeeting:)];
        joinButton.controlSize = NSControlSizeSmall;
        joinButton.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
        // The blue of the agenda's video button when it's enabled.
        joinButton.bezelColor = Theme.todayCellColor;
        _meetingRow = [NSStackView stackViewWithViews:@[_meetingIcon, _meetingHost]];
        [_meetingRow addView:joinButton inGravity:NSStackViewGravityTrailing];
        _meetingRow.alignment = NSLayoutAttributeCenterY;
        _meetingRow.spacing = 7;

        // The calendar (or a reminder's list): its color as a dot and
        // its name, like Calendar.
        _calendarDot = [NSImageView new];
        _calendarDot.accessibilityElement = NO;
        _calendarName = [NSTextField labelWithString:@""];
        _calendarName.lineBreakMode = NSLineBreakByTruncatingTail;
        [_calendarName setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        _calendarRow = [NSStackView stackViewWithViews:@[_calendarDot, _calendarName]];
        _calendarRow.alignment = NSLayoutAttributeCenterY;
        _calendarRow.spacing = 7;
        
        NSStackView* (^stack)(NSArray<NSView *> *, NSEdgeInsets) = ^NSStackView* (NSArray<NSView *> *views, NSEdgeInsets insets) {
            NSStackView *stack = [NSStackView stackViewWithViews:views];
            stack.orientation = NSUserInterfaceLayoutOrientationVertical;
            stack.alignment = NSLayoutAttributeLeading;
            stack.spacing = kInset;
            stack.edgeInsets = insets;
            stack.translatesAutoresizingMaskIntoConstraints = NO;
            return stack;
        };

        // Like Calendar, the title and time stay at the top and
        // the other sections scroll below them.
        _titleSection = [[AgendaPopoverSection alloc] initWithRows:@[titleHolder]];
        _header = stack(@[_titleSection,
                          [[AgendaPopoverSection alloc] initWithRows:@[_duration, _recurrence]]],
                        NSEdgeInsetsMake(kInset, kInset, kInset, kInset));
        _body = stack(@[[[AgendaPopoverSection alloc] initWithRows:@[_location]],
                        [[AgendaPopoverSection alloc] initWithRows:@[_meetingRow]],
                        [[AgendaPopoverSection alloc] initWithRows:@[_attendees]],
                        [[AgendaPopoverSection alloc] initWithRows:@[_calendarRow]],
                        [[AgendaPopoverSection alloc] initWithRows:@[_note]],
                        [[AgendaPopoverSection alloc] initWithRows:@[_URL]]],
                      NSEdgeInsetsMake(0, kInset, kInset, kInset));
        _sections = [_header.arrangedSubviews arrayByAddingObjectsFromArray:_body.arrangedSubviews];

        // The title section sits by the popover's top corners, so its
        // corners can be concentric with them. All sections use the
        // radius that gives. (Sections in the scroll view can't work
        // it out themselves: the scroll view is a container with its
        // own corners, and they aren't worked out again as it scrolls.)
        // See also -popoverDidShow.
        __weak AgendaPopoverVC *weakSelf = self;
        _titleSection.concentricRadiusChanged = ^(CGFloat radius) {
            AgendaPopoverVC *strongSelf = weakSelf;
            if (strongSelf == nil) return;
            for (AgendaPopoverSection *section in strongSelf->_sections) {
                section.layer.cornerRadius = radius;
            }
        };

        _scrollView = [NSScrollView new];
        _scrollView.drawsBackground = NO;
        _scrollView.hasVerticalScroller = YES;
        _scrollView.autohidesScrollers = YES;
        _scrollView.documentView = _body;

        _linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        _hiddenLinksRegex = [NSRegularExpression regularExpressionWithPattern:@"<((https?|rdar):\\/\\/[^\\s]+)>" options:NSRegularExpressionCaseInsensitive error:NULL];
        _messageLinksRegex = [NSRegularExpression regularExpressionWithPattern:@"message:%3\\S+" options:NSRegularExpressionCaseInsensitive error:NULL];
        // An opening or closing tag a rich text editor would write,
        // e.g. <br>, <a href="...">, </p>. Not <https://...>.
        _htmlTagRegex = [NSRegularExpression regularExpressionWithPattern:@"</?(a|b|i|u|s|em|strong|br|p|div|span|ul|ol|li|font|h[1-6]|table|thead|tbody|tr|th|td|hr|img|blockquote|pre|code|sup|sub|strike|center|html|html-blob|body)(\\s[^<>]*)?/?>" options:NSRegularExpressionCaseInsensitive error:NULL];
    }
    return self;
}

- (void)loadView
{
    NSView *view = [NSView new];
    [view addSubview:_header];
    [view addSubview:_scrollView];
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:view metrics:nil views:NSDictionaryOfVariableBindings(_header, _scrollView)];
    [vfl :@"H:|[_header]|"];
    [vfl :@"H:|[_scrollView]|"];
    [vfl :@"V:|[_header][_scrollView]|"];

    // The popover has hasFullSizeContent=YES. Use the
    // safeAreaLayoutGuide of a view that paints its background
    // according to the Theme to inset our content. This paints
    // the popover's full background, including the arrow.
    view.translatesAutoresizingMaskIntoConstraints = NO;
    MoThemeView *v = [MoThemeView new];
    [v addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.bottomAnchor],
        [view.leftAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.leftAnchor],
        [view.rightAnchor constraintEqualToAnchor:v.safeAreaLayoutGuide.rightAnchor],
    ]];
    self.view = v;
}

- (NSSize)size
{
    // The header and body (see -loadView), plus the safe area. The
    // body is hidden when none of its sections show.
    CGFloat h = self.view.safeAreaInsets.left + self.view.safeAreaInsets.right;
    CGFloat v = self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom;
    NSSize header = _header.fittingSize;
    CGFloat bodyHeight = _scrollView.hidden ? 0 : _body.fittingSize.height;
    return NSMakeSize(header.width + h, MIN(header.height + bodyHeight + v, kMaxPopoverHeight));
}

- (void)popoverDidShow
{
    // AppKit works out the title section's corners before the popover
    // has its final size, and doesn't do it again after (on macOS 27).
    // So the radius is often 0 or nearly the popover's. Have it worked
    // out again now.
    [_titleSection invalidateCornerConfiguration];

    [self makeRoomForScroller];

    NSView *docView = _scrollView.documentView;
    [docView scrollPoint:NSMakePoint(0, NSHeight(docView.bounds))];
    [_scrollView flashScrollers];

    // Prevent _note from eating key presses (like esc and delete).
    [self.view.window makeFirstResponder:_btnDelete];
}

- (void)deleteClicked:(NSButton *)sender
{
    // The delete button disappears(?!?!) after being clicked (macOS 11).
    // It's actually still there. You can click it. But it isn't drawn.
    // This bizarre buggy behavior seems to affect borderless buttons.
    // So we insanely toggle bordered on/off to make sure the button shows.
    sender.bordered = YES;
    sender.bordered = NO;
    if (self.deleteHandler) self.deleteHandler();
}

- (void)makeRoomForScroller
{
    // When scroll bars always show, the scroller sits beside the body
    // instead of over it, and only when the body has to scroll, that
    // is, when the popover is as tall as it can be. Then, like
    // Calendar, narrow the body's sections to make room, and keep the
    // header full width. (On macOS 27, +scrollerWidthForControlSize:
    // scrollerStyle: is 17 for overlay scrollers too, so check the
    // style.)
    if (_scrollView.hidden || _scrollView.scrollerStyle != NSScrollerStyleLegacy) return;
    [self.view layoutSubtreeIfNeeded];
    if (NSHeight(_body.frame) <= NSHeight(_scrollView.contentView.bounds)) return;
    [self setBodyWidth:kTextWidth - [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy]];
    // The text is taller now. Lay the body out at its new height, so
    // -popoverDidShow scrolls to its real top.
    [self.view layoutSubtreeIfNeeded];
}

// Set the width of the body's rows and the width its text wraps to.
- (void)setBodyWidth:(CGFloat)width
{
    for (AgendaPopoverSection *section in _body.arrangedSubviews) {
        [section setRowWidth:width];
    }
    for (AgendaPopoverTextView *textView in @[_location, _note, _URL]) {
        [textView setWrapWidth:width];
    }
}

// Size the text, icons and spacing to the agenda's text size setting.
- (void)updateSizes
{
    // Space above and below a separator, and between a section's rows.
    CGFloat spacing = SizePref.agendaPopoverSectionSpacing;
    for (AgendaPopoverSection *section in _sections) {
        section.spacing = spacing;
    }

    CGFloat fontSize = SizePref.fontSize;
    NSFont *font = [NSFont systemFontOfSize:fontSize];
    _title.font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightSemibold];
    _duration.font = font;
    _recurrence.font = font;
    _meetingHost.font = font;
    _calendarName.font = font;
    // The same size as the ⌫ character it replaced, and the meeting
    // icon's weight.
    _btnDelete.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:fontSize + 3 weight:NSFontWeightMedium];
    _meetingIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:fontSize weight:NSFontWeightMedium];
}

- (void)populateWithEventInfo:(EventInfo *)info
{
    [self updateSizes];

    NSString *title = @"";
    NSString *duration = @"";
    NSString *recurrence = @"";

    // info.item is the event or the reminder. Only events have
    // attendees and can be deleted here. A reminder has just a
    // due date, which may have no time, like an all-day event.
    EKCalendarItem *item = info.item;
    BOOL isAllDay = info.isRealAllDay;
    NSDate *startDate = info.startDate;
    NSDate *endDate   = info.endDate;

    if (info && item) {
        if (item.title) title = item.title;
    }
    NSAttributedString *notes = [self notesTextOfItem:item];

    // Hide the rows with nothing to show, then the sections with
    // no rows showing. The title and duration always show.
    _location.hidden = !info.location;
    _recurrence.hidden = !item.hasRecurrenceRules;
    _attendees.hidden = !info.event.hasAttendees;
    _meetingRow.hidden = info.meetingURL == nil;
    _calendarRow.hidden = item.calendar == nil;
    _note.hidden = notes == nil;
    _URL.hidden = !item.URL;
    for (AgendaPopoverSection *section in _sections) {
        [section updateHidden];
    }
    _scrollView.hidden = !AnyViewShows(_body.arrangedSubviews);

    // Full width, unless the body turns out to need room for a
    // scroller. See -makeRoomForScroller.
    [self setBodyWidth:kTextWidth];

    // Hide delete button IF event doesn't allow modification.
    _btnDelete.hidden = !info.event.calendar.allowsContentModifications;

    duration = DateRangeString(startDate, endDate, isAllDay);
    // If the event is not All-day and the start and end dates are
    // different, put them on different lines.
    // The – is U+2013 (en-dash) and the space is U+2009 (thin space)
    if (!isAllDay) {
        NSDateComponents *start = [NSCalendar.currentCalendar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:startDate];
        NSDateComponents *end = [NSCalendar.currentCalendar components:NSCalendarUnitMonth | NSCalendarUnitDay fromDate:endDate];
        if (start.day != end.day || start.month != end.month) {
            duration = [duration stringByReplacingOccurrencesOfString:@"– " withString:@"–\n"];
        }
    }
    // Recurrence.
    if (item.hasRecurrenceRules) {
        recurrence = [NSString stringWithFormat:@"%@ ", NSLocalizedString(@"Repeat:", nil)];
        EKRecurrenceRule *rule = item.recurrenceRules.firstObject;
        NSString *frequency = @"✓";
        switch (rule.frequency) {
            case EKRecurrenceFrequencyDaily:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Day", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Days", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyWeekly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Week", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Weeks", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyMonthly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Month", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Months", nil), rule.interval];
                break;
            case EKRecurrenceFrequencyYearly:
                frequency = rule.interval == 1
                    ? NSLocalizedString(@"Every Year", nil)
                    : [NSString stringWithFormat:NSLocalizedString(@"Every %zd Years", nil), rule.interval];
                break;
            default:
                break;
        }
        recurrence = [recurrence stringByAppendingString:frequency];
        if (rule.recurrenceEnd) {
            if (rule.recurrenceEnd.endDate) {
                NSDate *repeatEnd = rule.recurrenceEnd.endDate;
                NSString *endRecurrence = [NSString stringWithFormat:@"\n%@ %@", NSLocalizedString(@"End Repeat:", nil), DateRangeString(repeatEnd, repeatEnd, YES)];
                recurrence = [recurrence stringByAppendingString:endRecurrence];
            }
            if (rule.recurrenceEnd.occurrenceCount) {
                NSString *endRecurrence = [NSString stringWithFormat:@"\n%@ ×%zd", NSLocalizedString(@"End Repeat:", nil), rule.recurrenceEnd.occurrenceCount];
                recurrence = [recurrence stringByAppendingString:endRecurrence];
            }
        }
    }
    
    // Location
    if (info.location) {
        [_location setAttributedText:[self textWithString:info.location isHTML:NO]];
    }
    
    // Attendees
    if (info.event.hasAttendees) {
        
        // Block returns YES if participant is the event's organizer.
        BOOL (^ParticipantIsOrganizer)(EKParticipant*, EKParticipant*) = ^BOOL(EKParticipant *participant, EKParticipant *organizer) {
            // https://stackoverflow.com/a/17222036/111418
            return [participant.URL.resourceSpecifier isEqualToString:organizer.URL.resourceSpecifier];
        };
        
        // Sometimes info.event.organizer isn't in info.event.attendees.
        // Make an array of participants that definitely has the organizer.
        NSMutableArray<EKParticipant *> *participants = [NSMutableArray new];
        if (info.event.organizer) {
            [participants addObject:info.event.organizer];
        }
        for (EKParticipant *p in info.event.attendees) {
            // Don't double-add the organizer.
            if (!ParticipantIsOrganizer(p, info.event.organizer)) {
                [participants addObject:p];
            }
        }
        // Sort participants with organizer first, then accepted, pending,
        // and the rest (like declined). The sort is stable, so participants
        // with the same rank stay in the event's order.
        NSInteger (^Rank)(EKParticipant *) = ^NSInteger(EKParticipant *participant) {
            if (ParticipantIsOrganizer(participant, info.event.organizer)) return 0;
            if (participant.participantStatus == EKParticipantStatusAccepted) return 1;
            if (participant.participantStatus == EKParticipantStatusPending) return 2;
            return 3;
        };
        NSArray<EKParticipant *> *sortedParticipants = [participants sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(EKParticipant *p1, EKParticipant *p2) {
            NSInteger rank1 = Rank(p1), rank2 = Rank(p2);
            return rank1 < rank2 ? NSOrderedAscending : rank1 > rank2 ? NSOrderedDescending : NSOrderedSame;
        }];
        // Too many to show? Leave room for the line saying how many more,
        // which is then at least 2, never "1 more".
        NSArray<EKParticipant *> *shownParticipants = sortedParticipants;
        if (sortedParticipants.count > kMaxAttendeeLines) {
            shownParticipants = [sortedParticipants subarrayWithRange:NSMakeRange(0, kMaxAttendeeLines - 1)];
        }
        NSMutableArray<NSView *> *attendeesArray = [NSMutableArray new];
        for (EKParticipant *participant in shownParticipants) {
            NSString *orgIcon = ParticipantIsOrganizer(participant, info.event.organizer) ? @"•" : @"";
            NSString *statusIcon = @"􀁜"; // questionmark.circle (Requires SF fonts to see)
            NSColor *textColor = Theme.agendaEventDateTextColor;
            if (participant.participantStatus == EKParticipantStatusAccepted) {
                statusIcon = @"􀁢"; // checkmark.circle (Requires SF fonts to see)
                textColor = NSColor.systemGreenColor;
            }
            if (participant.participantStatus == EKParticipantStatusDeclined) {
                statusIcon = @"􀁐"; // x.circle (Requires SF fonts to see)
                textColor = NSColor.systemRedColor;
            }

            // Status icons are in the embedded font Mow.otf, CANNOT compress.
            NSTextField *statusLabel = [NSTextField labelWithString:statusIcon];
            statusLabel.textColor = textColor;
            statusLabel.font = [NSFont fontWithName:@"Mow" size:SizePref.fontSize];
            [statusLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

            // EKParticipant name and URL.resourceSpecifier (email addr)
            // are nullable (why?...). Make sure we don't try to create
            // a label with a null string.
            NSString *participantString = participant.name;
            if (!participantString) {
                participantString = participant.URL.resourceSpecifier; // email addr
                if (!participantString) participantString = @"***";
            }

            // Participant uses system font, CAN compress.
            NSTextField *participantLabel = [NSTextField labelWithString:participantString];
            participantLabel.selectable = YES;
            participantLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            participantLabel.textColor = Theme.agendaEventTextColor;
            participantLabel.font = [NSFont systemFontOfSize:SizePref.fontSize];
            [participantLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

            // Organizer icon uses system font, CANNOT compress.
            NSTextField *organizerLabel = [NSTextField labelWithString:orgIcon];
            organizerLabel.textColor = Theme.agendaEventTextColor;
            organizerLabel.font = [NSFont systemFontOfSize:SizePref.fontSize];
            [organizerLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

            // Horizontally stack status icon, participant, organizer indicator.
            NSStackView *attendee = [NSStackView stackViewWithViews:@[statusLabel, participantLabel, organizerLabel]];
            attendee.alignment = NSLayoutAttributeBaseline;
            attendee.detachesHiddenViews = NO;
            [attendee setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
            [attendee setClippingResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
            [attendeesArray addObject:attendee];
        }
        // Say how many attendees aren't shown.
        if (shownParticipants.count < sortedParticipants.count) {
            NSString *count = [NSNumberFormatter localizedStringFromNumber:@(sortedParticipants.count - shownParticipants.count) numberStyle:NSNumberFormatterDecimalStyle];
            NSTextField *moreLabel = [NSTextField labelWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ more", @"Last line of a long list of invitees in the event popover: the number of invitees not shown, e.g. 1,650 more"), count]];
            moreLabel.textColor = Theme.agendaEventDateTextColor;
            moreLabel.font = [NSFont systemFontOfSize:SizePref.fontSize];
            [attendeesArray addObject:moreLabel];
        }
        // Vertically stack attendees.
        [_attendees setViews:attendeesArray inGravity:NSStackViewGravityBottom];
    }

    // Notes
    if (notes) {
        [_note setAttributedText:notes];
    }

    // URL
    if (item.URL) {
        [_URL setAttributedText:[self textWithString:item.URL.absoluteString isHTML:NO]];
    }
    
    _title.stringValue = title;
    _duration.stringValue = duration;
    _recurrence.stringValue = recurrence;
    
    _title.textColor = Theme.agendaEventTextColor;
    _duration.textColor = Theme.agendaEventTextColor;
    _recurrence.textColor = Theme.agendaEventTextColor;

    // Only events have meetings. Show the host, like teams.microsoft.com.
    _meetingURL = info.meetingURL;
    NSString *host = _meetingURL.host.lowercaseString;
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    _meetingHost.stringValue = host ?: _meetingURL.absoluteString ?: @"";
    _meetingHost.textColor = Theme.agendaEventTextColor;

    _calendarDot.image = CalendarDotImage(item.calendar.color);
    _calendarName.stringValue = item.calendar.title ?: @"";
    _calendarName.textColor = Theme.agendaEventTextColor;
}

- (void)joinMeeting:(id)sender
{
    // Open the meeting in its app if it's installed, like the
    // agenda's video button.
    if (_meetingURL) [NSWorkspace.sharedWorkspace openURL:AppLinkForMeetingURL(_meetingURL)];
}

// The item's notes as text to show, or nil if there's nothing to show.
- (NSAttributedString *)notesTextOfItem:(EKCalendarItem *)item
{
    NSString *notes = [item.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (notes.length == 0) return nil;
    // Notes are plain text, except those made in a rich text
    // editor (like Google Calendar's), which are HTML. Parsing
    // plain text as HTML would drop anything in <angle brackets>
    // and change text like &copy, so only parse notes with tags.
    BOOL isHTML = [_htmlTagRegex firstMatchInString:notes options:kNilOptions range:NSMakeRange(0, notes.length)] != nil;
    NSAttributedString *text = [self textWithString:notes isHTML:isHTML];
    // HTML can show nothing, like the <br> Google Calendar can leave
    // when a description is cleared.
    NSString *shown = [text.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return shown.length > 0 ? text : nil;
}

// The string as text to show, with links.
- (NSAttributedString *)textWithString:(NSString *)string isHTML:(BOOL)isHTML
{
    // We will detect mail message URLs with _messageLinksRegex. These URLs
    // link directly to specific messages. They may contain fragments that look
    // like standard URLs that are picked up by _linkDetector. In order to avoid
    // conflicts, we keep an array of NSRanges for matched message URLs. When
    // we go to match standard URLs, we will only match those whose NSRanges
    // don't intersect (overlap) with message URLs.
    NSMutableArray *messageLinkRanges = [NSMutableArray new];

    NSMutableAttributedString *attrString;
    if (isHTML) {
        // Ugly hack to deal with Microsoft's insane habit of putting links
        // in angle brackets, making them invisible when rendereed as HTML.
        string = [_hiddenLinksRegex stringByReplacingMatchesInString:string options:kNilOptions range:NSMakeRange(0, string.length) withTemplate:@"&lt;$1&gt;"];

        string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
        NSData *htmlData = [string dataUsingEncoding:NSUnicodeStringEncoding];
        attrString = [[NSMutableAttributedString alloc] initWithHTML:htmlData documentAttributes:nil];
    }
    else {
        attrString = [[NSMutableAttributedString alloc] initWithString:string];
    }

    [attrString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:SizePref.fontSize] range:NSMakeRange(0, attrString.length)];
    [attrString addAttribute:NSForegroundColorAttributeName value:Theme.agendaEventTextColor range:NSMakeRange(0, attrString.length)];
    [_messageLinksRegex enumerateMatchesInString:attrString.string options:kNilOptions range:NSMakeRange(0, attrString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *link = [attrString.string substringWithRange:result.range];
        [attrString addAttribute:NSLinkAttributeName value:link range:result.range];
        [messageLinkRanges addObject:[NSValue valueWithRange:result.range]];
    }];
    [_linkDetector enumerateMatchesInString:attrString.string options:kNilOptions range:NSMakeRange(0, attrString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        // Make sure result.range doesn't intersect (overlap) with the
        // range of a message URL matched by _messageLinksRegex.
        BOOL resultOverlapsAMessageLink = NO;
        for (NSValue *val in messageLinkRanges) {
            NSRange intersection = NSIntersectionRange(val.rangeValue, result.range);
            if (intersection.length != 0) {
                resultOverlapsAMessageLink = YES;
                break;
            }
        }
        if (!resultOverlapsAMessageLink) {
            [attrString addAttribute:NSLinkAttributeName value:result.URL.absoluteString range:result.range];
        }
    }];
    return attrString;
}

@end
