
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>

#import "CalculatorHistoryViewController.h"
#import "CalculatorHistoryRecordManager.h"
#import "CalculatorHistoryRecord.h"
#import "CalculatorHistoryRecordCell.h"
#import "CalculatorHistoryExpressionFormatter.h"
#import "Localize.h"
#import "Utils.h"

#import "Extensions/UIFont+Rounded.h"
#import "Extensions/DisplayValue+CalculatorHistory.h"

#define WEAK_BOOM 1519

@implementation CalculatorHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.title = [Localize localizedStringForKey:@"HISTORY"];
    self.navigationController.navigationBar.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    self.navigationController.navigationBar.tintColor = [UIColor systemOrangeColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[Localize localizedStringForKey:@"DONE"] style:UIBarButtonItemStylePlain target:self action:@selector(_dismiss)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[Localize localizedStringForKey:@"CLEAR"] style:UIBarButtonItemStylePlain target:self action:@selector(clearHistory)];

    [self _setupSubviews];

    [_tableView registerClass:[CalculatorHistoryRecordCell class] forCellReuseIdentifier:@"HistoryCell"];
}

- (void)_setupSubviews {
    _tableView = [[UITableView alloc] init];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor systemBackgroundColor];
    _tableView.tableFooterView = [UITableView new]; // Hide empty cells
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    _data = [[CalculatorHistoryRecordManager sharedManager] historyRecords];
    if (_data.count == 0) {
        [self _addNoHistoryLabel];
    }
}

- (void)_dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearHistory {
    if (_data.count == 0) return;
    AudioServicesPlaySystemSound(WEAK_BOOM);

    [[CalculatorHistoryRecordManager sharedManager] clearHistory];
    _data = @[];
    [_tableView reloadData];
    [self _addNoHistoryLabel];
}

- (void)setDisplayValue:(NSString *)value {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.usesGroupingSeparator = NO;
    numberFormatter.maximumFractionDigits = 15;
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;    

    NSDictionary *options = @{
        CalculateKeyNumberFormatter: numberFormatter,
    };

    CalculateResult *result = [objc_getClass("Calculate") evaluate:value options:options];
    result.locales = @[[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    NSString *formattedResult = [result formattedResult];

    NSLog(@"Evaluated expression: %@, got result: %@", value, formattedResult);

    DisplayValue *displayValue = [[objc_getClass("Calculator.DisplayValue") alloc] initWithValue:formattedResult
                                                                                        userEntered:YES];

    NSLog(@"Created DisplayValue: %@", displayValue);

    CalculatorController *controller = MSHookIvar<CalculatorController *>([UIApplication sharedApplication].delegate, "controller");
    NSLog(@"Got controller: %@", controller);

    CalculatorModel *model = MSHookIvar<CalculatorModel *>(controller, "model");
    NSLog(@"Got model: %@", model);

    [controller calculatorModel:model didUpdateDisplayValue:displayValue shouldFlashDisplay:NO];
    MSHookIvar<DisplayValue *>(model, "displayValue") = displayValue;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _data.count;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    AudioServicesPlaySystemSound(WEAK_BOOM);

    CalculatorHistoryRecord *record = [[CalculatorHistoryRecordManager sharedManager] historyRecords][indexPath.row];
    if (!record) return;

    NSString *expression = [record expression];
    NSString *result = [[[expression componentsSeparatedByString:@"="] lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    [self setDisplayValue:result];

    [tableView setEditing:NO animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CalculatorHistoryRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HistoryCell"];

    if (_data.count == 0) return cell;

    CalculatorHistoryRecord *record = _data[indexPath.row];

    NSArray *dateComponents = [[CalculatorHistoryExpressionFormatter sharedFormatter] relativeDateComponentsFromDate:[record date]];
    cell.textLabel.text = [dateComponents firstObject];
    cell.detailTextLabel.text = [dateComponents lastObject];

    [cell.resultLabel setAttributedText:[[CalculatorHistoryExpressionFormatter sharedFormatter] formatEquation:[record expression]]];
    [cell.resultLabel setTextAlignment:NSTextAlignmentRight];

    return cell;
}


- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:[Localize localizedStringForKey:@"DELETE"]
                                                                             handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[CalculatorHistoryRecordManager sharedManager] removeRecordAtIndex:indexPath.row];
        _data = [[CalculatorHistoryRecordManager sharedManager] historyRecords];
        [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

        if (_data.count == 0) [self _addNoHistoryLabel];
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash.fill"];

    UIContextualAction *copyAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:[Localize localizedStringForKey:@"COPY_RESULT"]
                                                                           handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        AudioServicesPlaySystemSound(WEAK_BOOM);

        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        CalculatorHistoryRecord *record = _data[indexPath.row];


        NSInteger index = [[record expression] rangeOfString:@"=" options:NSBackwardsSearch].location;
        pasteboard.string = [record.expression substringFromIndex:index + 2];
        [_tableView setEditing:NO animated:YES];
    }];
    copyAction.image = [UIImage systemImageNamed:@"doc.on.doc.fill"];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, copyAction]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    CalculatorHistoryRecord *record = _data[indexPath.row];

    NSInteger index = [[record expression] rangeOfString:@"=" options:NSBackwardsSearch].location;
    NSString *expression = [record.expression substringToIndex:index];
    NSString *result = [record.expression substringFromIndex:index + 2];

    UIImage *copyImage = [[[UIImage systemImageNamed:@"doc.on.doc"]
                       imageWithTintColor:[UIColor systemOrangeColor]]
                      imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    UIAction *copyExpressionAction = [UIAction actionWithTitle:[Localize localizedStringForKey:@"COPY_EXPRESSION"]
                                                         image:copyImage
                                                    identifier:nil
                                                       handler:^(__kindof UIAction * _Nonnull action) {
        AudioServicesPlaySystemSound(WEAK_BOOM);

        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = expression;
    }];

    if (@available(iOS 15.0, *)) {
        copyExpressionAction.subtitle = [NSString stringWithFormat:@"ATTR://%@", [record expression]];
    }

    UIAction *copyResultAction = [UIAction actionWithTitle:[Localize localizedStringForKey:@"COPY_RESULT"]
                                                     image:copyImage
                                                identifier:nil
                                                   handler:^(__kindof UIAction * _Nonnull action) {
        AudioServicesPlaySystemSound(WEAK_BOOM);

        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        
        pasteboard.string = result;
    }];

    if (@available(iOS 15.0, *)) {
        copyResultAction.subtitle = result;
    }

    UIAction *deleteAction = [UIAction actionWithTitle:[Localize localizedStringForKey:@"DELETE"]
                                                 image:[UIImage systemImageNamed:@"trash.fill"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [[CalculatorHistoryRecordManager sharedManager] removeRecordAtIndex:indexPath.row];
        _data = [[CalculatorHistoryRecordManager sharedManager] historyRecords];
        [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

        if (_data.count == 0) [self _addNoHistoryLabel];
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;

    UIMenu *copySubgroup = [UIMenu menuWithTitle:@""
                                           image:nil
                                      identifier:nil
                                         options:UIMenuOptionsDisplayInline
                                        children:@[copyExpressionAction, copyResultAction]];

    UIMenu *deleteSubgroup = [UIMenu menuWithTitle:@""
                                             image:nil
                                        identifier:nil
                                           options:UIMenuOptionsDisplayInline
                                          children:@[deleteAction]];

    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[copySubgroup, deleteSubgroup]];
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return menu;
    }];
}

- (BOOL)_canShowWhileLocked {
    return YES;
}

- (void)_addNoHistoryLabel {
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.centerXAnchor constraintEqualToAnchor:_tableView.centerXAnchor],
        [view.centerYAnchor constraintEqualToAnchor:_tableView.centerYAnchor constant:-(self.navigationController.navigationBar.frame.size.height + 25)],
        [view.widthAnchor constraintEqualToConstant:200],
        [view.heightAnchor constraintEqualToConstant:200]
    ]];

    UIImageView *clockView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"clock"]];
    clockView.tintColor = [UIColor systemGray2Color];
    clockView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:clockView];
    [NSLayoutConstraint activateConstraints:@[
        [clockView.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [clockView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [clockView.widthAnchor constraintEqualToConstant:50],
        [clockView.heightAnchor constraintEqualToConstant:50]
    ]];

    UILabel *label = [[UILabel alloc] init];
    label.text = [Localize localizedStringForKey:@"NO_HISTORY"];
    label.font = [UIFont roundedFontOfSize:24 weight:UIFontWeightRegular];
    [view addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor systemGray2Color];
    label.numberOfLines = 0;

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
        [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [label.topAnchor constraintEqualToAnchor:clockView.bottomAnchor constant:10],
        [label.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
}

@end
