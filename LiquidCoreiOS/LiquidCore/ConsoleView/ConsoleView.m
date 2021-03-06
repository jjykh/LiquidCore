//
//  ConsoleView.m
//  LiquidCoreiOS
//
/*
 Copyright (c) 2018 Eric Lange. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ConsoleView.h"

@implementation ConsoleView

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self xibSetup];
        [self initView];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self xibSetup];
        [self initView];
    }
    return self;
}

- (void) xibSetup
{
    UIView* view = [self loadViewFromNib];
    view.frame = self.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
}

- (UIView *)loadViewFromNib
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UINib *nib = [UINib nibWithNibName:@"ConsoleView" bundle:bundle];
    UIView *view = [nib instantiateWithOwner:self options:nil][0];
    
    return view;
}

- (void) initView
{
    self.downHistory.enabled = NO;
    self.upHistory.enabled = NO;
    self.command.selected = YES;
}

- (void) layoutSubviews
{
    [super layoutSubviews];
    [self.command setDelegate:self];
    [self.command setCommandDelegate:self];
    [self.command becomeFirstResponder];
    [self.console setDelegate:self];
    self.command.smartQuotesType = UITextSmartQuotesTypeNo;
    self.command.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITextInputAssistantItem* item = [self.command inputAssistantItem];
    item.leadingBarButtonGroups = @[];
    item.trailingBarButtonGroups = @[];
    
    NSString *someString = @"1234567890\n1234567890";
    UIFont *font = [UIFont fontWithName:@"Menlo" size:12.f];
    CGSize stringBoundingBox = [someString sizeWithAttributes:@{ NSFontAttributeName : font }];

    // FIXME: This doesn't quite work right.  It always seems off by a character or two.
    double heightChar = stringBoundingBox.height / 2;
    double widthChar = stringBoundingBox.width / 10;
    
    double heightBox = self.console.bounds.size.height - self.console.layoutMargins.bottom - self.console.layoutMargins.top;
    double widthBox = self.console.bounds.size.width - self.console.layoutMargins.left - self.console.layoutMargins.right;

    int numCols = floor(widthBox / widthChar);
    int numLines = floor(heightBox / heightChar);
    [self resize:numLines columns:numCols];
}

// override me
- (void) resize:(int)rows columns:(int)columns
{
    
}

- (void) textViewDidChangeSelection:(UITextView *)textView
{
    NSRange bottom = NSMakeRange(self.console.text.length -1, 1);
    [self.console scrollRangeToVisible:bottom];
}

- (void) onUpArrow
{
    if (self.upHistory.enabled) {
        self.item --;
        self.command.text = [self.history objectAtIndex:self.item];
        if (self.item == 0) {
            self.upHistory.enabled = NO;
        }
        self.downHistory.enabled = YES;
        self.command.selected = YES;
    }
}

- (void) onDownArrow
{
    if (self.downHistory.enabled) {
        self.item ++;
        if (self.item >= self.history.count) {
            self.downHistory.enabled = NO;
            self.command.text = @"";
        } else {
            self.command.text = [self.history objectAtIndex:self.item];
        }
        self.upHistory.enabled = YES;
        self.command.selected = YES;
    }
}

- (void) onReturnKey
{
    NSString *cmd = [self.command.text stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    if (cmd.length > 0) {
        NSString *display = [NSString stringWithFormat:@"%C[30;1m> %@", 0x001B, cmd];
        
        [self.console println:display];
        [self.command setText:@""];
        if (self.history == nil) {
            self.history = [[NSMutableArray alloc] init];
        }
        [self.history addObject:cmd];
        self.item = self.history.count;
        self.upHistory.enabled = YES;
        self.downHistory.enabled = NO;
        
        [self processCommand:cmd];
        self.command.selected = YES;
    }
}

- (void) processCommand:(NSString *)cmd
{
    
}

#pragma UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.command) {
        [textField resignFirstResponder];
        [self onReturnKey];
        return NO;
    }
    return YES;
}

#pragma IBActions

- (IBAction)onUpHistoryTouch:(id)sender
{
    [self onUpArrow];
}

- (IBAction)onDownHistoryTouch:(id)sender
{
    [self onDownArrow];
}

@end
