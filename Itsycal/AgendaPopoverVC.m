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

#pragma mark -
#pragma mark AgendaPopoverVC

// =========================================================================
// AgendaPopoverVC
// =========================================================================

#define POPOVER_TEXT_WIDTH 280

@implementation AgendaPopoverVC
{
    NSGridView  *_grid;
    NSTextField *_title;
    NSTextField *_duration;
    NSTextField *_recurrence;
    NSTextView *_location;
    NSTextView *_note;
    NSTextView *_URL;
    NSStackView *_attendees;
    NSScrollView *_scrollView;
    NSDataDetector *_linkDetector;
    NSRegularExpression *_hiddenLinksRegex;
    NSRegularExpression *_messageLinksRegex;
    NSRegularExpression *_htmlTagRegex;
    NSLayoutConstraint *_locHeight;
    NSLayoutConstraint *_noteHeight;
    NSLayoutConstraint *_URLHeight;
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
    NSBox* (^separator)(void) = ^NSBox* {
        // Need a big width for separator to show up reliably in NSGridView.
        NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 999, 1)];
        separator.boxType = NSBoxSeparator;
        return separator;
    };
    NSTextView* (^textview)(void) = ^NSTextView* {
        NSTextView *txtview = [NSTextView new];
        txtview.editable = NO;
        txtview.selectable = YES;
        txtview.drawsBackground = NO;
        txtview.textContainer.lineFragmentPadding = 0;
        txtview.textContainer.size = NSMakeSize(POPOVER_TEXT_WIDTH, FLT_MAX);
        return txtview;
    };
    self = [super init];
    if (self) {
        _title = label();
        _duration = label();
        _recurrence = label();
        
        _location = textview();
        _note = textview();
        _URL = textview();
        
        _btnDelete = [NSButton new];
        _btnDelete.title = @"⌫";
        _btnDelete.focusRingType = NSFocusRingTypeNone;
        _btnDelete.bordered = NO;
        _btnDelete.contentTintColor = NSColor.secondaryLabelColor;
        
        NSView *titleHolder = [NSView new];
        [titleHolder addSubview:_title];
        [titleHolder addSubview:_btnDelete];
        MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:titleHolder metrics:nil views:NSDictionaryOfVariableBindings(_title, _btnDelete)];
        [vfl :@"H:|[_title]-(>=10)-[_btnDelete]|" :NSLayoutFormatAlignAllCenterY];
        [vfl :@"V:|[_title]|"];
        [titleHolder.widthAnchor constraintEqualToConstant:POPOVER_TEXT_WIDTH].active = YES;
        
        _attendees = [NSStackView new];
        _attendees.orientation = NSUserInterfaceLayoutOrientationVertical;
        _attendees.alignment = NSLayoutAttributeLeft;
        _attendees.spacing = 4;
        _attendees.detachesHiddenViews = NO;
        [_attendees setClippingResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
        
        _grid = [NSGridView gridViewWithViews:@[@[titleHolder],  // row 0
                                                @[_location],    // 1
                                                @[separator()],  // 2
                                                @[_duration],    // 3
                                                @[_recurrence],  // 4
                                                @[separator()],  // 5
                                                @[_attendees],   // 6
                                                @[separator()],  // 7
                                                @[_note],        // 8
                                                @[_URL]]];       // 9
        _grid.rowSpacing = 8;
        _grid.translatesAutoresizingMaskIntoConstraints = NO;
        [_grid cellForView:_btnDelete].xPlacement = NSGridCellPlacementCenter;
        [_grid columnAtIndex:0].width = POPOVER_TEXT_WIDTH;
        [_grid columnAtIndex:0].leadingPadding  = 10;
        [_grid columnAtIndex:0].trailingPadding = 14;

        _scrollView = [NSScrollView new];
        _scrollView.drawsBackground = NO;
        _scrollView.hasVerticalScroller = YES;
        _scrollView.documentView = _grid;
        _scrollView.verticalScroller = [ThemedScroller new];

        _linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        _hiddenLinksRegex = [NSRegularExpression regularExpressionWithPattern:@"<((https?|rdar):\\/\\/[^\\s]+)>" options:NSRegularExpressionCaseInsensitive error:NULL];
        _messageLinksRegex = [NSRegularExpression regularExpressionWithPattern:@"message:%3\\S+" options:NSRegularExpressionCaseInsensitive error:NULL];
        // An opening or closing tag a rich text editor would write,
        // e.g. <br>, <a href="...">, </p>. Not <https://...>.
        _htmlTagRegex = [NSRegularExpression regularExpressionWithPattern:@"</?(a|b|i|u|s|em|strong|br|p|div|span|ul|ol|li|font|h[1-6]|table|thead|tbody|tr|th|td|hr|img|blockquote|pre|code|sup|sub|strike|center|html|html-blob|body)(\\s[^<>]*)?/?>" options:NSRegularExpressionCaseInsensitive error:NULL];
        
        _locHeight = [_location.heightAnchor constraintEqualToConstant:100];
        _locHeight.active = YES;
        _noteHeight = [_note.heightAnchor constraintEqualToConstant:100];
        _noteHeight.active = YES;
        _URLHeight = [_URL.heightAnchor constraintEqualToConstant:100];
        _URLHeight.active = YES;
    }
    return self;
}

- (void)loadView
{
    NSView *view = [NSView new];
    [view addSubview:_scrollView];
    MoVFLHelper *vfl = [[MoVFLHelper alloc] initWithSuperview:view metrics:nil views:NSDictionaryOfVariableBindings(_scrollView)];
    [vfl :@"H:|[_scrollView]|"];
    [vfl :@"V:|-8-[_scrollView]-8-|"];

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
    // See -loadView. Vertial padding top+bottom = 16.
    // Also take into account the safe area.
    CGFloat h = self.view.safeAreaInsets.left + self.view.safeAreaInsets.right;
    CGFloat v = self.view.safeAreaInsets.top + self.view.safeAreaInsets.bottom;
    return NSMakeSize(_grid.fittingSize.width + h,
                      _grid.fittingSize.height + v + 16);
}

- (void)scrollToTopAndFlashScrollers
{
    NSView *docView = _scrollView.documentView;
    [docView scrollPoint:NSMakePoint(0, NSHeight(docView.bounds))];
    [_scrollView flashScrollers];
}

- (void)populateWithEventInfo:(EventInfo *)info
{
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
    
    // Hide location row IF there's no location string.
    [_grid rowAtIndex:1].hidden = !info.location;
    
    // Hide recurrence row IF there's no recurrence rule.
    [_grid rowAtIndex:4].hidden = !item.hasRecurrenceRules;
    
    // Hide attendees row and separator above it IF there are no attendees.
    [_grid rowAtIndex:5].hidden = !info.event.hasAttendees;
    [_grid rowAtIndex:6].hidden = !info.event.hasAttendees;

    // Hide note row and separator row above it IF there's no note AND no URL.
    [_grid rowAtIndex:7].hidden = !item.hasNotes && !item.URL;
    [_grid rowAtIndex:8].hidden = !item.hasNotes;
    
    // Hide URL row IF there's no URL.
    [_grid rowAtIndex:9].hidden = !item.URL;

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
        // Append a space to force correct height calc on first display.
        // Same technique used for the URL field below.
        [self populateTextView:_location withString:[info.location stringByAppendingString:@" "] isHTML:NO heightConstraint:_locHeight];
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
        // Sort participants with organizer first, then accepted, pending, declined.
        NSArray<EKParticipant *> *sortedParticipants = [participants sortedArrayUsingComparator:^NSComparisonResult(EKParticipant * p1, EKParticipant *p2) {
            if (ParticipantIsOrganizer(p1, info.event.organizer)) return NSOrderedAscending;
            if (ParticipantIsOrganizer(p2, info.event.organizer)) return NSOrderedDescending;
            if (p1.participantStatus == EKParticipantStatusAccepted) return NSOrderedAscending;
            if (p2.participantStatus == EKParticipantStatusAccepted) return NSOrderedDescending;
            if (p1.participantStatus == EKParticipantStatusPending) return NSOrderedAscending;
            if (p2.participantStatus == EKParticipantStatusPending) return NSOrderedDescending;
            return NSOrderedDescending;
        }];
        NSMutableArray<NSStackView *> *attendeesArray = [NSMutableArray new];
        for (EKParticipant *participant in sortedParticipants) {
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
        // Vertically stack attendees.
        [_attendees setViews:attendeesArray inGravity:NSStackViewGravityBottom];
    }

    // Notes
    if (item.hasNotes) {
        NSString *trimmedNotes = [item.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmedNotes isEqualToString:@""]) {
            // Hide note row and separator row above it, provided no URL.
            [_grid rowAtIndex:7].hidden = !item.URL;
            [_grid rowAtIndex:8].hidden = YES;
        }
        else {
            // Notes are plain text, except those made in a rich text
            // editor (like Google Calendar's), which are HTML. Parsing
            // plain text as HTML would drop anything in <angle brackets>
            // and change text like &copy, so only parse notes with tags.
            BOOL isHTML = [_htmlTagRegex firstMatchInString:trimmedNotes options:kNilOptions range:NSMakeRange(0, trimmedNotes.length)] != nil;
            // Append a space to force correct height calc on first display.
            // Same technique used for the URL field below.
            [self populateTextView:_note withString:[trimmedNotes stringByAppendingString:@" "] isHTML:isHTML heightConstraint:_noteHeight];
        }
    }

    // URL
    if (item.URL) {
        // HACK: append a space at end of URL to force correct height calc. Without
        // this, height is sometimes wrong on first display.
        NSString *absURL = [NSString stringWithFormat:@"%@ ", item.URL.absoluteString];
        [self populateTextView:_URL withString:absURL isHTML:NO heightConstraint:_URLHeight];
    }
    
    _title.stringValue = title;
    _duration.stringValue = duration;
    _recurrence.stringValue = recurrence;
    
    _title.font = [NSFont systemFontOfSize:SizePref.fontSize weight:NSFontWeightSemibold];
    _duration.font = [NSFont systemFontOfSize:SizePref.fontSize];
    _recurrence.font = _duration.font;
    _btnDelete.font  = [NSFont systemFontOfSize:SizePref.fontSize+3];

    _title.textColor = Theme.agendaEventTextColor;
    _duration.textColor = Theme.agendaEventTextColor;
    _recurrence.textColor = Theme.agendaEventTextColor;
}

- (void)populateTextView:(NSTextView *)textView withString:(NSString *)string isHTML:(BOOL)isHTML heightConstraint:(NSLayoutConstraint *)constraint
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
    textView.textStorage.attributedString = attrString;
    [self setHeightConstraint:constraint forTextView:textView];
}

- (void)setHeightConstraint:(NSLayoutConstraint *)constraint forTextView:(NSTextView *)textView
{
    // Force layout and then calculate text height.
    // stackoverflow.com/a/44969138/111418
    (void) [textView.layoutManager glyphRangeForTextContainer:textView.textContainer];
    NSRect textRect = [textView.layoutManager usedRectForTextContainer:textView.textContainer];
    constraint.constant = textRect.size.height;
}

@end
