#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const PreferredModel = @"iPad5,3";
// SidecarCore 의 unsupportedModels 목록(macOS 26.6 정적 분석 기준)과 제품명.
static NSDictionary<NSString *, NSString *> *UnsupportedModelNames(void) {
    static NSDictionary *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @{
            @"iPad4,1": @"iPad Air", @"iPad4,2": @"iPad Air", @"iPad4,3": @"iPad Air",
            @"iPad4,4": @"iPad mini 2", @"iPad4,5": @"iPad mini 2", @"iPad4,6": @"iPad mini 2",
            @"iPad4,7": @"iPad mini 3", @"iPad4,8": @"iPad mini 3", @"iPad4,9": @"iPad mini 3",
            @"iPad5,1": @"iPad mini 4", @"iPad5,2": @"iPad mini 4",
            @"iPad5,3": @"iPad Air 2", @"iPad5,4": @"iPad Air 2",
            @"iPad6,11": @"iPad (5세대)", @"iPad6,12": @"iPad (5세대)",
        };
    });
    return names;
}

static NSString * const SelectedDeviceKey = @"selectedDeviceID";
static NSString * const CustomConfigKey = @"useCustomConfig";
static NSString * const ConfigWidthKey = @"configWidth";
static NSString * const ConfigHeightKey = @"configHeight";
static NSString * const ConfigScaleKey = @"configScale";
static NSString * const ConfigFramerateKey = @"configFramerate";
static NSString * const ConfigMinBitrateKey = @"configMinBitrateMbps";
static NSString * const ConfigMaxBitrateKey = @"configMaxBitrateMbps";
static NSString * const ConfigLowLatencyKey = @"configLowLatency";

typedef id (*SendObject0)(id, SEL);
typedef id (*SendObject1)(id, SEL, id);
typedef id (*SendObjectBool)(id, SEL, BOOL);
typedef void (*SendConnect)(id, SEL, id, void (^)(NSError *));
typedef void (*SendDisconnect)(id, SEL, id, void (^)(NSError *));
typedef void (*SendConnectWithConfig)(id, SEL, id, id, void (^)(NSError *));
typedef void (*SendVoidObject)(id, SEL, id);
typedef void (*SendVoidSize)(id, SEL, CGSize);
typedef void (*SendVoidDouble)(id, SEL, double);
typedef CGSize (*SendSize0)(id, SEL);
typedef double (*SendDouble0)(id, SEL);

static NSError *LocalError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"local.sidecarlab.OldPadSidecar"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface SidecarController : NSObject
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextView *logView;
@property(nonatomic, strong) NSButton *connectButton;
@property(nonatomic, strong) NSButton *disconnectButton;
@property(nonatomic, strong) NSPopUpButton *devicePopup;
@property(nonatomic, strong) NSButton *refreshButton;
@property(nonatomic, strong) NSButton *customCheckbox;
@property(nonatomic, strong) NSTextField *widthField;
@property(nonatomic, strong) NSTextField *heightField;
@property(nonatomic, strong) NSTextField *scaleField;
@property(nonatomic, strong) NSTextField *framerateField;
@property(nonatomic, strong) NSTextField *minBitrateField;
@property(nonatomic, strong) NSTextField *maxBitrateField;
@property(nonatomic, strong) NSButton *lowLatencyCheckbox;
@property(nonatomic, copy) NSArray *devices;
@property(nonatomic, strong) NSMenuItem *connectMenuItem;
@property(nonatomic, strong) NSMenuItem *disconnectMenuItem;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) id device;
@property(nonatomic, strong) id manager;
@property(nonatomic, strong) NSTimer *monitorTimer;
@property(nonatomic) BOOL connected;
@property(nonatomic) BOOL working;
@property(nonatomic) NSInteger consecutiveMissingChecks;
@property(nonatomic) BOOL testMode;
- (instancetype)initWithTestMode:(BOOL)testMode;
- (void)showWindow:(id)sender;
- (void)connectAction:(id)sender;
- (void)disconnectAction:(id)sender;
- (void)disconnectForTermination:(void (^)(void))completion;
@end

@implementation SidecarController

- (instancetype)initWithTestMode:(BOOL)testMode {
    self = [super init];
    if (self) {
        _testMode = testMode;
        [self buildWindow];
        [self buildStatusMenu];
        [self setIdleState:@"연결 대기 중"];
        [self appendLog:@"앱을 시작했습니다. iPad의 잠금을 풀고 기기를 선택하세요."];
        [self refreshDevices];
    }
    return self;
}

- (NSTextField *)addLabel:(NSString *)text at:(NSRect)frame to:(NSView *)content {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    [content addSubview:label];
    return label;
}

- (NSTextField *)addFieldAt:(NSRect)frame placeholder:(NSString *)placeholder to:(NSView *)content {
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.frame = frame;
    field.placeholderString = placeholder;
    field.alignment = NSTextAlignmentRight;
    [content addSubview:field];
    return field;
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 520, 600);
    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"OldPad Sidecar";
    self.window.releasedWhenClosed = NO;
    [self.window center];

    NSView *content = self.window.contentView;

    NSTextField *title = [NSTextField labelWithString:@"Sidecar 연결"];
    title.frame = NSMakeRect(28, 544, 464, 30);
    title.font = [NSFont boldSystemFontOfSize:22];
    [content addSubview:title];

    [self addLabel:@"기기" at:NSMakeRect(28, 508, 40, 22) to:content];
    self.devicePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(72, 505, 312, 26) pullsDown:NO];
    self.devicePopup.target = self;
    self.devicePopup.action = @selector(deviceSelectionChanged:);
    [content addSubview:self.devicePopup];
    self.refreshButton = [NSButton buttonWithTitle:@"새로고침"
                                            target:self
                                            action:@selector(refreshDevicesAction:)];
    self.refreshButton.frame = NSMakeRect(392, 504, 100, 28);
    [content addSubview:self.refreshButton];

    self.customCheckbox = [NSButton checkboxWithTitle:@"연결 설정 직접 지정 (끄면 기본 협상값 사용)"
                                               target:self
                                               action:@selector(customToggled:)];
    self.customCheckbox.frame = NSMakeRect(28, 468, 464, 22);
    [content addSubview:self.customCheckbox];

    [self addLabel:@"해상도" at:NSMakeRect(44, 436, 60, 22) to:content];
    self.widthField = [self addFieldAt:NSMakeRect(112, 434, 70, 24) placeholder:@"너비" to:content];
    [self addLabel:@"×" at:NSMakeRect(188, 436, 16, 22) to:content];
    self.heightField = [self addFieldAt:NSMakeRect(206, 434, 70, 24) placeholder:@"높이" to:content];
    [self addLabel:@"배율" at:NSMakeRect(300, 436, 40, 22) to:content];
    self.scaleField = [self addFieldAt:NSMakeRect(344, 434, 60, 24) placeholder:@"2" to:content];
    [self addLabel:@"x" at:NSMakeRect(408, 436, 16, 22) to:content];

    [self addLabel:@"주사율" at:NSMakeRect(44, 404, 60, 22) to:content];
    self.framerateField = [self addFieldAt:NSMakeRect(112, 402, 70, 24) placeholder:@"자동" to:content];
    [self addLabel:@"Hz" at:NSMakeRect(188, 404, 30, 22) to:content];
    self.lowLatencyCheckbox = [NSButton checkboxWithTitle:@"저지연" target:nil action:NULL];
    self.lowLatencyCheckbox.frame = NSMakeRect(300, 403, 100, 22);
    [content addSubview:self.lowLatencyCheckbox];

    [self addLabel:@"비트레이트" at:NSMakeRect(44, 372, 70, 22) to:content];
    self.minBitrateField = [self addFieldAt:NSMakeRect(112, 370, 70, 24) placeholder:@"최소" to:content];
    [self addLabel:@"~" at:NSMakeRect(188, 372, 16, 22) to:content];
    self.maxBitrateField = [self addFieldAt:NSMakeRect(206, 370, 70, 24) placeholder:@"최대" to:content];
    [self addLabel:@"Mbps (비우면 기본값)" at:NSMakeRect(284, 372, 200, 22) to:content];

    NSTextField *description = [NSTextField labelWithString:
        @"해상도·배율은 iPad에 맞는 값을 넣어야 합니다. 연결 후 협상된 값은 자동으로 기억됩니다."];
    description.frame = NSMakeRect(28, 340, 464, 22);
    description.textColor = NSColor.secondaryLabelColor;
    description.font = [NSFont systemFontOfSize:11];
    [content addSubview:description];

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.frame = NSMakeRect(28, 295, 464, 28);
    self.statusLabel.font = [NSFont boldSystemFontOfSize:16];
    [content addSubview:self.statusLabel];

    self.connectButton = [NSButton buttonWithTitle:@"연결"
                                            target:self
                                            action:@selector(connectAction:)];
    self.connectButton.frame = NSMakeRect(28, 250, 140, 34);
    self.connectButton.bezelStyle = NSBezelStyleRounded;
    self.connectButton.keyEquivalent = @"\r";
    [content addSubview:self.connectButton];

    self.disconnectButton = [NSButton buttonWithTitle:@"연결 해제"
                                               target:self
                                               action:@selector(disconnectAction:)];
    self.disconnectButton.frame = NSMakeRect(180, 250, 140, 34);
    self.disconnectButton.bezelStyle = NSBezelStyleRounded;
    [content addSubview:self.disconnectButton];

    NSTextField *logTitle = [NSTextField labelWithString:@"상태 기록"];
    logTitle.frame = NSMakeRect(28, 218, 464, 20);
    logTitle.font = [NSFont boldSystemFontOfSize:13];
    [content addSubview:logTitle];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(28, 28, 464, 184)];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    self.logView = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
    self.logView.editable = NO;
    self.logView.selectable = YES;
    self.logView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.logView.textContainerInset = NSMakeSize(8, 7);
    scroll.documentView = self.logView;
    [content addSubview:scroll];

    [self loadSettings];
}

- (void)buildStatusMenu {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"Sidecar";
    self.statusItem.button.toolTip = @"OldPad Sidecar";

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"OldPad Sidecar"];
    [menu addItemWithTitle:@"창 열기" action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    self.connectMenuItem = [menu addItemWithTitle:@"연결"
                                           action:@selector(connectAction:)
                                    keyEquivalent:@""];
    self.disconnectMenuItem = [menu addItemWithTitle:@"연결 해제"
                                              action:@selector(disconnectAction:)
                                       keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"종료" action:@selector(terminate:) keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action != NULL) item.target = (item.action == @selector(terminate:)) ? NSApp : self;
    }
    self.statusItem.menu = menu;
}

- (void)showWindow:(id)sender {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)appendLog:(NSString *)message {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self appendLog:message]; });
        return;
    }
    NSString *time = [NSDateFormatter localizedStringFromDate:NSDate.date
                                                     dateStyle:NSDateFormatterNoStyle
                                                     timeStyle:NSDateFormatterMediumStyle];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", time, message];
    [self.logView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line]];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.string.length, 0)];
    fputs(line.UTF8String, stdout);
    fflush(stdout);
}

- (void)refreshControls {
    self.connectButton.enabled = !self.connected && !self.working;
    self.connectMenuItem.enabled = self.connectButton.enabled;
    self.disconnectButton.enabled = self.connected && !self.working;
    self.disconnectMenuItem.enabled = self.disconnectButton.enabled;
    BOOL editable = !self.connected && !self.working;
    self.devicePopup.enabled = editable;
    self.refreshButton.enabled = editable;
    self.customCheckbox.enabled = editable;
    BOOL custom = editable && self.customCheckbox.state == NSControlStateValueOn;
    for (NSControl *control in @[self.widthField, self.heightField, self.scaleField,
                                 self.framerateField, self.minBitrateField,
                                 self.maxBitrateField, self.lowLatencyCheckbox]) {
        control.enabled = custom;
    }
}

- (void)setIdleState:(NSString *)message {
    self.connected = NO;
    self.working = NO;
    self.statusLabel.stringValue = message;
    self.statusItem.button.title = @"Sidecar";
    [self refreshControls];
}

- (void)setWorkingState:(NSString *)message {
    self.working = YES;
    self.statusLabel.stringValue = message;
    self.statusItem.button.title = @"Sidecar…";
    [self refreshControls];
}

- (void)setConnectedState {
    self.connected = YES;
    self.working = NO;
    self.consecutiveMissingChecks = 0;
    self.statusLabel.stringValue = @"연결됨 — 설정 확인 중…";
    self.statusItem.button.title = @"Sidecar ✓";
    [self refreshControls];
    [self startMonitor];
    [self updateNegotiatedConfigAfterDelay];
}

- (NSArray *)fetchDevices:(NSError **)errorOut {
    const char *frameworkPath = "/System/Library/PrivateFrameworks/SidecarCore.framework/Versions/A/SidecarCore";
    if (dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) == NULL) {
        if (errorOut) *errorOut = LocalError(1, @"SidecarCore를 불러오지 못했습니다.");
        return nil;
    }

    Class deviceClass = NSClassFromString(@"SidecarDevice");
    SEL fetchSelector = NSSelectorFromString(@"allDevicesByForcingFetchFromRelay:");
    if (!deviceClass || ![deviceClass respondsToSelector:fetchSelector]) {
        if (errorOut) *errorOut = LocalError(2, @"Sidecar 기기 검색 기능을 찾지 못했습니다.");
        return nil;
    }
    return ((SendObjectBool)objc_msgSend)((id)deviceClass, fetchSelector, YES) ?: @[];
}

- (NSString *)stringForKey:(NSString *)key ofDevice:(id)device {
    SEL selector = NSSelectorFromString(key);
    id value = [device respondsToSelector:selector] ? ((SendObject0)objc_msgSend)(device, selector) : nil;
    return value ? [value description] : @"";
}

- (NSString *)modelOfDevice:(id)device {
    return [self stringForKey:@"model" ofDevice:device];
}

- (NSString *)identifierOfDevice:(id)device {
    return [self stringForKey:@"identifier" ofDevice:device];
}

// 개인 기기 이름 대신 제품명을 보여 준다. 표에 없는 모델은 식별자를 그대로 쓴다.
- (NSString *)labelForModel:(NSString *)model {
    return UnsupportedModelNames()[model] ?: (model.length ? model : @"알 수 없는 기기");
}

- (void)refreshDevicesAction:(id)sender {
    [self refreshDevices];
}

- (void)refreshDevices {
    self.refreshButton.enabled = NO;
    [self appendLog:@"기기를 검색합니다."];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSError *error = nil;
            NSArray *found = [self fetchDevices:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refreshControls];
                if (error) {
                    [self appendLog:error.localizedDescription];
                    return;
                }
                [self applyDevices:found];
            });
        }
    });
}

- (void)applyDevices:(NSArray *)found {
    NSString *wanted = [NSUserDefaults.standardUserDefaults stringForKey:SelectedDeviceKey];
    if (self.devicePopup.selectedItem.representedObject) {
        wanted = self.devicePopup.selectedItem.representedObject;
    }
    self.devices = found;
    [self.devicePopup removeAllItems];
    NSInteger selectedIndex = -1;
    NSInteger preferredIndex = -1;
    NSMutableDictionary<NSString *, NSNumber *> *totals = [NSMutableDictionary dictionary];
    for (id candidate in found) {
        NSString *label = [self labelForModel:[self modelOfDevice:candidate]];
        totals[label] = @(totals[label].integerValue + 1);
    }
    NSMutableDictionary<NSString *, NSNumber *> *seen = [NSMutableDictionary dictionary];
    for (id candidate in found) {
        NSString *model = [self modelOfDevice:candidate];
        NSString *identifier = [self identifierOfDevice:candidate];
        NSString *label = [self labelForModel:model];
        NSString *title = label;
        if (totals[label].integerValue > 1) {
            seen[label] = @(seen[label].integerValue + 1);
            title = [NSString stringWithFormat:@"%@ (%@)", label, seen[label]];
        }
        if (UnsupportedModelNames()[model]) title = [title stringByAppendingString:@" — 공식 미지원"];
        [self.devicePopup addItemWithTitle:title];
        self.devicePopup.lastItem.representedObject = identifier;
        NSInteger index = self.devicePopup.numberOfItems - 1;
        if ([identifier isEqualToString:wanted]) selectedIndex = index;
        if (preferredIndex < 0 && [model isEqualToString:PreferredModel]) preferredIndex = index;
    }
    if (found.count == 0) {
        [self.devicePopup addItemWithTitle:@"검색된 기기가 없습니다"];
        [self appendLog:@"검색된 기기가 없습니다. 잠금 해제와 연결 상태를 확인하세요."];
    } else {
        NSInteger index = selectedIndex >= 0 ? selectedIndex : (preferredIndex >= 0 ? preferredIndex : 0);
        [self.devicePopup selectItemAtIndex:index];
        [self appendLog:[NSString stringWithFormat:@"기기 %lu대를 찾았습니다: %@",
                         (unsigned long)found.count, [self.devicePopup.itemTitles componentsJoinedByString:@", "]]];
    }
    [self deviceSelectionChanged:nil];
}

- (id)selectedDevice {
    NSString *identifier = self.devicePopup.selectedItem.representedObject;
    if (!identifier) return nil;
    for (id candidate in self.devices) {
        if ([[self identifierOfDevice:candidate] isEqualToString:identifier]) return candidate;
    }
    return nil;
}

- (NSString *)defaultsKey:(NSString *)key forDevice:(id)device {
    return [NSString stringWithFormat:@"%@.%@", key, device ? [self modelOfDevice:device] : @"none"];
}

- (void)deviceSelectionChanged:(id)sender {
    id device = [self selectedDevice];
    NSString *identifier = self.devicePopup.selectedItem.representedObject;
    if (identifier) [NSUserDefaults.standardUserDefaults setObject:identifier forKey:SelectedDeviceKey];
    // 사용자가 기기를 바꿨거나 칸이 비어 있을 때만 기기별 마지막 협상값을 채운다.
    BOOL hasValues = self.widthField.stringValue.length > 0 || self.heightField.stringValue.length > 0 ||
                     self.scaleField.stringValue.length > 0;
    if (sender == nil && hasValues) return;
    NSDictionary *last = device
        ? [NSUserDefaults.standardUserDefaults dictionaryForKey:[self defaultsKey:@"lastNegotiated" forDevice:device]]
        : nil;
    if (last) {
        self.widthField.stringValue = [last[@"width"] description] ?: @"";
        self.heightField.stringValue = [last[@"height"] description] ?: @"";
        self.scaleField.stringValue = [last[@"scale"] description] ?: @"";
    } else if (device && [[self modelOfDevice:device] isEqualToString:PreferredModel]) {
        self.widthField.stringValue = @"1024";
        self.heightField.stringValue = @"768";
        self.scaleField.stringValue = @"2";
    }
}

- (void)customToggled:(id)sender {
    [self refreshControls];
}

- (void)loadSettings {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.customCheckbox.state = [defaults boolForKey:CustomConfigKey] ? NSControlStateValueOn : NSControlStateValueOff;
    self.lowLatencyCheckbox.state = [defaults boolForKey:ConfigLowLatencyKey] ? NSControlStateValueOn : NSControlStateValueOff;
    NSDictionary<NSString *, NSTextField *> *fields = @{
        ConfigWidthKey: self.widthField, ConfigHeightKey: self.heightField,
        ConfigScaleKey: self.scaleField, ConfigFramerateKey: self.framerateField,
        ConfigMinBitrateKey: self.minBitrateField, ConfigMaxBitrateKey: self.maxBitrateField,
    };
    for (NSString *key in fields) {
        fields[key].stringValue = [defaults stringForKey:key] ?: @"";
    }
}

- (void)saveSettings {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:self.customCheckbox.state == NSControlStateValueOn forKey:CustomConfigKey];
    [defaults setBool:self.lowLatencyCheckbox.state == NSControlStateValueOn forKey:ConfigLowLatencyKey];
    NSDictionary<NSString *, NSTextField *> *fields = @{
        ConfigWidthKey: self.widthField, ConfigHeightKey: self.heightField,
        ConfigScaleKey: self.scaleField, ConfigFramerateKey: self.framerateField,
        ConfigMinBitrateKey: self.minBitrateField, ConfigMaxBitrateKey: self.maxBitrateField,
    };
    for (NSString *key in fields) {
        [defaults setObject:fields[key].stringValue forKey:key];
    }
}

// 빈 칸이면 nil, 숫자가 아니거나 0 이하면 invalid 로 표시한다.
- (NSNumber *)positiveNumberFromField:(NSTextField *)field invalid:(BOOL *)invalid {
    NSString *text = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (text.length == 0) return nil;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    double value = 0;
    if (![scanner scanDouble:&value] || !scanner.isAtEnd || value <= 0) {
        *invalid = YES;
        return nil;
    }
    return @(value);
}

// 직접 지정을 끈 경우 nil 을 돌려주며 기본 연결을 쓴다.
- (id)buildConfigForDevice:(id)device error:(NSError **)errorOut {
    if (self.customCheckbox.state != NSControlStateValueOn) return nil;

    BOOL invalid = NO;
    NSNumber *width = [self positiveNumberFromField:self.widthField invalid:&invalid];
    NSNumber *height = [self positiveNumberFromField:self.heightField invalid:&invalid];
    NSNumber *scale = [self positiveNumberFromField:self.scaleField invalid:&invalid];
    NSNumber *framerate = [self positiveNumberFromField:self.framerateField invalid:&invalid];
    NSNumber *minBitrate = [self positiveNumberFromField:self.minBitrateField invalid:&invalid];
    NSNumber *maxBitrate = [self positiveNumberFromField:self.maxBitrateField invalid:&invalid];
    if (invalid) {
        if (errorOut) *errorOut = LocalError(6, @"설정 값은 0보다 큰 숫자여야 합니다.");
        return nil;
    }
    if (!width || !height || !scale) {
        if (errorOut) *errorOut = LocalError(7, @"해상도(너비·높이)와 배율을 입력하세요.");
        return nil;
    }
    if (minBitrate && maxBitrate && minBitrate.doubleValue > maxBitrate.doubleValue) {
        if (errorOut) *errorOut = LocalError(8, @"최소 비트레이트가 최대보다 클 수 없습니다.");
        return nil;
    }

    Class configClass = NSClassFromString(@"SidecarDisplayConfig");
    id config = configClass ? [[configClass alloc] init] : nil;
    if (!config) {
        if (errorOut) *errorOut = LocalError(9, @"Sidecar 설정 객체를 만들지 못했습니다.");
        return nil;
    }
    ((SendVoidObject)objc_msgSend)(config, NSSelectorFromString(@"setDevice:"), device);
    ((SendVoidSize)objc_msgSend)(config, NSSelectorFromString(@"setSize:"),
                                 CGSizeMake(width.doubleValue, height.doubleValue));
    ((SendVoidDouble)objc_msgSend)(config, NSSelectorFromString(@"setScale:"), scale.doubleValue);
    if (framerate) {
        ((SendVoidObject)objc_msgSend)(config, NSSelectorFromString(@"setFramerate:"), @(framerate.integerValue));
    }
    // 입력은 Mbps, 설정 값은 bps 로 넘긴다.
    if (minBitrate) {
        ((SendVoidObject)objc_msgSend)(config, NSSelectorFromString(@"setTxMinBitrate:"),
                                       @((long long)(minBitrate.doubleValue * 1000000)));
    }
    if (maxBitrate) {
        ((SendVoidObject)objc_msgSend)(config, NSSelectorFromString(@"setTxMaxBitrate:"),
                                       @((long long)(maxBitrate.doubleValue * 1000000)));
    }
    if (self.lowLatencyCheckbox.state == NSControlStateValueOn) {
        ((SendVoidObject)objc_msgSend)(config, NSSelectorFromString(@"setLowLatency:"), @YES);
    }
    return config;
}

- (id)findManager:(NSError **)errorOut {
    Class managerClass = NSClassFromString(@"SidecarDisplayManager");
    SEL selector = NSSelectorFromString(@"sharedManager");
    if (!managerClass || ![managerClass respondsToSelector:selector]) {
        if (errorOut) *errorOut = LocalError(5, @"Sidecar 연결 관리자를 찾지 못했습니다.");
        return nil;
    }
    return ((SendObject0)objc_msgSend)((id)managerClass, selector);
}

- (void)connectAction:(id)sender {
    if (self.connected || self.working) return;
    id target = [self selectedDevice];
    if (!target) {
        [self appendLog:@"연결할 기기를 선택하세요. 목록이 비어 있으면 새로고침을 누르세요."];
        [self showWindow:nil];
        return;
    }
    NSError *configError = nil;
    id config = [self buildConfigForDevice:target error:&configError];
    if (configError) {
        [self appendLog:configError.localizedDescription];
        [self showWindow:nil];
        return;
    }
    [self saveSettings];
    [self setWorkingState:@"기기에 연결하는 중…"];
    [self appendLog:@"연결 요청을 준비합니다."];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSError *managerError = nil;
            id displayManager = [self findManager:&managerError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (managerError) {
                    [self setIdleState:@"연결 준비 실패"];
                    [self appendLog:managerError.localizedDescription];
                    [self showWindow:nil];
                    return;
                }
                self.device = target;
                self.manager = displayManager;
                [self beginConnectionWithConfig:config];
            });
        }
    });
}

- (void)beginConnectionWithConfig:(id)config {
    SEL defaultSelector = NSSelectorFromString(@"connectToDevice:completion:");
    SEL configSelector = NSSelectorFromString(@"connectToDevice:withConfig:completion:");
    SEL selector = config ? configSelector : defaultSelector;
    if (![self.manager respondsToSelector:selector]) {
        [self setIdleState:@"연결 기능을 찾지 못함"];
        [self appendLog:@"현재 macOS의 Sidecar 연결 메서드가 예상과 다릅니다."];
        return;
    }
    [self setWorkingState:@"Sidecar 연결 중…"];
    NSString *model = [self modelOfDevice:self.device];
    [self appendLog:[NSString stringWithFormat:@"%@ 기기로 %@ 연결을 요청했습니다.",
                     model, config ? @"사용자 설정" : @"기본"]];
    __weak typeof(self) weakSelf = self;
    void (^completion)(NSError *) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            if (error) {
                [self setIdleState:@"연결 실패"];
                [self appendLog:[NSString stringWithFormat:@"연결 실패: %@ (%ld)",
                                 error.localizedDescription, (long)error.code]];
                [self showWindow:nil];
                return;
            }
            [self setConnectedState];
            [self appendLog:@"Sidecar 영상 연결이 시작되었습니다."];
            if (self.testMode) [self scheduleTestDisconnect];
        });
    };
    if (config) {
        ((SendConnectWithConfig)objc_msgSend)(self.manager, selector, self.device, config, completion);
    } else {
        ((SendConnect)objc_msgSend)(self.manager, selector, self.device, completion);
    }
}

- (void)updateNegotiatedConfigAfterDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        if (!self.connected || !self.manager || !self.device) return;
        SEL configSelector = NSSelectorFromString(@"configForDevice:");
        id config = [self.manager respondsToSelector:configSelector]
            ? ((SendObject1)objc_msgSend)(self.manager, configSelector, self.device) : nil;
        if (!config) {
            self.statusLabel.stringValue = @"연결됨 — 기본 설정";
            [self appendLog:@"협상된 표시 설정은 별도로 조회되지 않았습니다."];
            return;
        }
        CGSize size = ((SendSize0)objc_msgSend)(config, NSSelectorFromString(@"size"));
        double scale = ((SendDouble0)objc_msgSend)(config, NSSelectorFromString(@"scale"));
        id rate = ((SendObject0)objc_msgSend)(config, NSSelectorFromString(@"framerate"));
        NSString *rateText = rate ? [rate description] : @"자동";
        [NSUserDefaults.standardUserDefaults setObject:@{
            @"width": @((NSInteger)size.width),
            @"height": @((NSInteger)size.height),
            @"scale": @(scale),
        } forKey:[self defaultsKey:@"lastNegotiated" forDevice:self.device]];
        self.statusLabel.stringValue = [NSString stringWithFormat:
            @"연결됨 — %.0f×%.0f @%.0fx / %@Hz", size.width, size.height, scale, rateText];
        [self appendLog:[NSString stringWithFormat:
            @"협상된 표시 설정: %.0f×%.0f, 배율 %.2fx, %@Hz",
            size.width, size.height, scale, rateText]];
    });
}

- (void)disconnectAction:(id)sender {
    [self disconnectWithCompletion:nil];
}

- (void)disconnectWithCompletion:(void (^)(void))completion {
    if (!self.connected || self.working || !self.manager || !self.device) {
        if (completion) completion();
        return;
    }
    [self setWorkingState:@"연결 해제 중…"];
    [self appendLog:@"연결 해제를 요청했습니다."];
    [self.monitorTimer invalidate];
    self.monitorTimer = nil;

    SEL selector = NSSelectorFromString(@"disconnectFromDevice:completion:");
    if (![self.manager respondsToSelector:selector]) {
        [self setIdleState:@"연결 해제 기능을 찾지 못함"];
        [self appendLog:@"앱을 종료하면 연결 프로세스가 함께 종료됩니다."];
        if (completion) completion();
        return;
    }
    __weak typeof(self) weakSelf = self;
    ((SendDisconnect)objc_msgSend)(self.manager, selector, self.device, ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) {
                if (completion) completion();
                return;
            }
            if (error && error.code != -102) {
                self.working = NO;
                [self refreshControls];
                self.statusLabel.stringValue = @"연결 해제 오류";
                [self appendLog:[NSString stringWithFormat:@"해제 오류: %@ (%ld)",
                                 error.localizedDescription, (long)error.code]];
            } else {
                [self setIdleState:@"연결 해제됨"];
                [self appendLog:@"연결이 안전하게 해제되었습니다."];
                self.device = nil;
                self.manager = nil;
            }
            if (completion) completion();
        });
    });
}

- (void)disconnectForTermination:(void (^)(void))completion {
    [self disconnectWithCompletion:completion];
}

- (void)startMonitor {
    [self.monitorTimer invalidate];
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                         target:self
                                                       selector:@selector(checkConnection:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)checkConnection:(NSTimer *)timer {
    if (!self.connected || self.working || !self.manager || !self.device) return;
    id manager = self.manager;
    id device = self.device;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        SEL selector = NSSelectorFromString(@"configForDevice:");
        id config = [manager respondsToSelector:selector]
            ? ((SendObject1)objc_msgSend)(manager, selector, device) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.connected) return;
            self.consecutiveMissingChecks = config ? 0 : self.consecutiveMissingChecks + 1;
            if (self.consecutiveMissingChecks >= 2) {
                [self.monitorTimer invalidate];
                self.monitorTimer = nil;
                [self setIdleState:@"연결이 종료됨"];
                [self appendLog:@"Sidecar 연결이 더 이상 확인되지 않습니다."];
                self.device = nil;
                self.manager = nil;
            }
        });
    });
}

- (void)scheduleTestDisconnect {
    [self appendLog:@"앱 시험: 10초 뒤 자동으로 연결을 해제합니다."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [self disconnectWithCompletion:^{ [NSApp terminate:nil]; }];
    });
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) SidecarController *controller;
@property(nonatomic) BOOL testMode;
@property(nonatomic) BOOL terminationPending;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.testMode = [NSProcessInfo.processInfo.arguments containsObject:@"--test-10-seconds"];
    self.controller = [[SidecarController alloc] initWithTestMode:self.testMode];
    [self.controller showWindow:nil];
    if (self.testMode) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ [self.controller connectAction:nil]; });
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (!self.controller.connected || self.terminationPending) return NSTerminateNow;
    self.terminationPending = YES;
    [self.controller disconnectForTermination:^{
        [sender replyToApplicationShouldTerminate:YES];
    }];
    return NSTerminateLater;
}

@end


int main(void) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
