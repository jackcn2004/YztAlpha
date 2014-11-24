//
//  FLEXViewHierarchyViewController.m
//  UICatalog
//
//  Created by Dal Rupnik on 24/11/14.
//  Copyright (c) 2014 f. All rights reserved.
//

#import "FLEXExplorerViewController.h"
#import "FLEXExplorerToolbar.h"
#import "FLEXToolbarItem.h"
#import "FLEXUtility.h"
#import "FLEXHierarchyTableViewController.h"
#import "FLEXInfoTableViewController.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXObjectExplorerFactory.h"

#import "FLEXViewHierarchyViewController.h"
#import "FLEXInfoTableViewController.h"

#import "FLEXManager.h"

@interface FLEXViewHierarchyViewController ()  <FLEXHierarchyTableViewControllerDelegate, FLEXViewControllerDelegate>

//
// Previous properties, to refactor
//

@property (nonatomic, strong) FLEXExplorerToolbar *explorerToolbar;

/// Gesture recognizer for dragging a view in move mode
@property (nonatomic, strong) UIPanGestureRecognizer *movePanGR;

/// Gesture recognizer for showing additional details on the selected view
@property (nonatomic, strong) UITapGestureRecognizer *detailsTapGR;

/// Only valid while a move pan gesture is in progress.
@property (nonatomic, assign) CGRect selectedViewFrameBeforeDragging;

/// Only valid while a toolbar drag pan gesture is in progress.
@property (nonatomic, assign) CGRect toolbarFrameBeforeDragging;

/// Borders of all the visible views in the hierarchy at the selection point.
/// The keys are NSValues with the correponding view (nonretained).
@property (nonatomic, strong) NSDictionary *outlineViewsForVisibleViews;

/// The actual views at the selection point with the deepest view last.
@property (nonatomic, strong) NSArray *viewsAtTapPoint;

/// The view that we're currently highlighting with an overlay and displaying details for.
@property (nonatomic, strong) UIView *selectedView;

/// A colored transparent overlay to indicate that the view is selected.
@property (nonatomic, strong) UIView *selectedViewOverlay;

/// All views that we're KVOing. Used to help us clean up properly.
@property (nonatomic, strong) NSMutableSet *observedViews;

@end

@implementation FLEXViewHierarchyViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self)
    {
        self.observedViews = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc
{
    for (UIView *view in _observedViews)
    {
        [self stopObservingView:view];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Toolbar
    self.explorerToolbar = [[FLEXExplorerToolbar alloc] init];
    CGSize toolbarSize = [self.explorerToolbar sizeThatFits:self.view.bounds.size];
    // Start the toolbar off below any bars that may be at the top of the view.
    CGFloat toolbarOriginY = 100.0;
    self.explorerToolbar.frame = CGRectMake(0.0, toolbarOriginY, toolbarSize.width, toolbarSize.height);
    self.explorerToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.explorerToolbar];
    
    [self setupToolbarActions];
    [self setupToolbarGestures];
    
    // View selection
    UITapGestureRecognizer *selectionTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionTap:)];
    [self.view addGestureRecognizer:selectionTapGR];
    
    // View moving
    self.movePanGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMovePan:)];
    self.movePanGR.enabled = self.currentMode == FLEXViewHierarchyModeMove;
    [self.view addGestureRecognizer:self.movePanGR];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateButtonStates];
}

#pragma mark - Status Bar Wrangling for iOS 7

// Try to get the preferred status bar properties from the app's root view controller (not us).
// In general, our window shouldn't be the key window when this view controller is asked about the status bar.
// However, we guard against infinite recursion and provide a reasonable default for status bar behavior in case our window is the keyWindow.

- (UIViewController *)viewControllerForStatusBarAndOrientationProperties
{
    UIViewController *viewControllerToAsk = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    
    // On iPhone, modal view controllers get asked
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        while (viewControllerToAsk.presentedViewController) {
            viewControllerToAsk = viewControllerToAsk.presentedViewController;
        }
    }
    
    return viewControllerToAsk;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIViewController *viewControllerToAsk = [self viewControllerForStatusBarAndOrientationProperties];
    UIStatusBarStyle preferredStyle = UIStatusBarStyleDefault;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        // We might need to foward to a child
        UIViewController *childViewControllerToAsk = [viewControllerToAsk childViewControllerForStatusBarStyle];
        while (childViewControllerToAsk && childViewControllerToAsk != viewControllerToAsk) {
            viewControllerToAsk = childViewControllerToAsk;
            childViewControllerToAsk = [viewControllerToAsk childViewControllerForStatusBarStyle];
        }
        
        preferredStyle = [viewControllerToAsk preferredStatusBarStyle];
    }
    return preferredStyle;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    UIViewController *viewControllerToAsk = [self viewControllerForStatusBarAndOrientationProperties];
    UIStatusBarAnimation preferredAnimation = UIStatusBarAnimationFade;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        preferredAnimation = [viewControllerToAsk preferredStatusBarUpdateAnimation];
    }
    return preferredAnimation;
}

- (BOOL)prefersStatusBarHidden
{
    UIViewController *viewControllerToAsk = [self viewControllerForStatusBarAndOrientationProperties];
    BOOL prefersHidden = NO;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        // Again, we might need to forward to a child
        UIViewController *childViewControllerToAsk = [viewControllerToAsk childViewControllerForStatusBarHidden];
        while (childViewControllerToAsk && childViewControllerToAsk != viewControllerToAsk) {
            viewControllerToAsk = childViewControllerToAsk;
            childViewControllerToAsk = [viewControllerToAsk childViewControllerForStatusBarHidden];
        }
        
        prefersHidden = [viewControllerToAsk prefersStatusBarHidden];
    }
    return prefersHidden;
}


#pragma mark - Rotation

- (NSUInteger)supportedInterfaceOrientations
{
    UIViewController *viewControllerToAsk = [self viewControllerForStatusBarAndOrientationProperties];
    NSUInteger supportedOrientations = [FLEXUtility infoPlistSupportedInterfaceOrientationsMask];
    if (viewControllerToAsk && viewControllerToAsk != self) {
        supportedOrientations = [viewControllerToAsk supportedInterfaceOrientations];
    }
    
    // The UIViewController docs state that this method must not return zero.
    // If we weren't able to get a valid value for the supported interface orientations, default to all supported.
    if (supportedOrientations == 0) {
        supportedOrientations = UIInterfaceOrientationMaskAll;
    }
    
    return supportedOrientations;
}

- (BOOL)shouldAutorotate
{
    UIViewController *viewControllerToAsk = [self viewControllerForStatusBarAndOrientationProperties];
    BOOL shouldAutorotate = YES;
    if (viewControllerToAsk && viewControllerToAsk != self) {
        shouldAutorotate = [viewControllerToAsk shouldAutorotate];
    }
    return shouldAutorotate;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    for (UIView *outlineView in [self.outlineViewsForVisibleViews allValues]) {
        outlineView.hidden = YES;
    }
    self.selectedViewOverlay.hidden = YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    for (UIView *view in self.viewsAtTapPoint) {
        NSValue *key = [NSValue valueWithNonretainedObject:view];
        UIView *outlineView = self.outlineViewsForVisibleViews[key];
        outlineView.frame = [self frameInLocalCoordinatesForView:view];
        if (self.currentMode == FLEXViewHierarchyModeSelect) {
            outlineView.hidden = NO;
        }
    }
    
    if (self.selectedView) {
        self.selectedViewOverlay.frame = [self frameInLocalCoordinatesForView:self.selectedView];
        self.selectedViewOverlay.hidden = NO;
    }
}


#pragma mark - Setter Overrides

- (void)setSelectedView:(UIView *)selectedView
{
    if (![_selectedView isEqual:selectedView]) {
        if (![self.viewsAtTapPoint containsObject:_selectedView]) {
            [self stopObservingView:_selectedView];
        }
        
        _selectedView = selectedView;
        
        [self beginObservingView:selectedView];
        
        // Update the toolbar and selected overlay
        self.explorerToolbar.selectedViewDescription = [FLEXUtility descriptionForView:selectedView includingFrame:YES];
        self.explorerToolbar.selectedViewOverlayColor = [FLEXUtility consistentRandomColorForObject:selectedView];;
        
        if (selectedView) {
            if (!self.selectedViewOverlay) {
                self.selectedViewOverlay = [[UIView alloc] init];
                [self.view addSubview:self.selectedViewOverlay];
                self.selectedViewOverlay.layer.borderWidth = 1.0;
            }
            UIColor *outlineColor = [FLEXUtility consistentRandomColorForObject:selectedView];
            self.selectedViewOverlay.backgroundColor = [outlineColor colorWithAlphaComponent:0.2];
            self.selectedViewOverlay.layer.borderColor = [outlineColor CGColor];
            self.selectedViewOverlay.frame = [self.view convertRect:selectedView.bounds fromView:selectedView];
            
            // Make sure the selected overlay is in front of all the other subviews except the toolbar, which should always stay on top.
            [self.view bringSubviewToFront:self.selectedViewOverlay];
            [self.view bringSubviewToFront:self.explorerToolbar];
        } else {
            [self.selectedViewOverlay removeFromSuperview];
            self.selectedViewOverlay = nil;
        }
        
        // Some of the button states depend on whether we have a selected view.
        [self updateButtonStates];
    }
}

- (void)setViewsAtTapPoint:(NSArray *)viewsAtTapPoint
{
    if (![_viewsAtTapPoint isEqual:viewsAtTapPoint]) {
        for (UIView *view in _viewsAtTapPoint) {
            if (view != self.selectedView) {
                [self stopObservingView:view];
            }
        }
        
        _viewsAtTapPoint = viewsAtTapPoint;
        
        for (UIView *view in viewsAtTapPoint) {
            [self beginObservingView:view];
        }
    }
}

- (void)setCurrentMode:(FLEXExplorerMode)currentMode
{
    if (_currentMode != currentMode) {
        _currentMode = currentMode;
        switch (currentMode) {
            case FLEXViewHierarchyModeDefault:
                [self removeAndClearOutlineViews];
                self.viewsAtTapPoint = nil;
                self.selectedView = nil;
                break;
                
            case FLEXViewHierarchyModeSelect:
                // Make sure the outline views are unhidden in case we came from the move mode.
                for (id key in self.outlineViewsForVisibleViews) {
                    UIView *outlineView = self.outlineViewsForVisibleViews[key];
                    outlineView.hidden = NO;
                }
                break;
                
            case FLEXViewHierarchyModeMove:
                // Hide all the outline views to focus on the selected view, which is the only one that will move.
                for (id key in self.outlineViewsForVisibleViews) {
                    UIView *outlineView = self.outlineViewsForVisibleViews[key];
                    outlineView.hidden = YES;
                }
                break;
        }
        self.movePanGR.enabled = currentMode == FLEXViewHierarchyModeMove;
        [self updateButtonStates];
    }
}


#pragma mark - View Tracking

- (void)beginObservingView:(UIView *)view
{
    // Bail if we're already observing this view or if there's nothing to observe.
    if (!view || [self.observedViews containsObject:view]) {
        return;
    }
    
    for (NSString *keyPath in [[self class] viewKeyPathsToTrack]) {
        [view addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }
    
    [self.observedViews addObject:view];
}

- (void)stopObservingView:(UIView *)view
{
    if (!view) {
        return;
    }
    
    for (NSString *keyPath in [[self class] viewKeyPathsToTrack]) {
        [view removeObserver:self forKeyPath:keyPath];
    }
    
    [self.observedViews removeObject:view];
}

+ (NSArray *)viewKeyPathsToTrack
{
    static NSArray *trackedViewKeyPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *frameKeyPath = NSStringFromSelector(@selector(frame));
        trackedViewKeyPaths = @[frameKeyPath];
    });
    return trackedViewKeyPaths;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updateOverlayAndDescriptionForObjectIfNeeded:object];
}

- (void)updateOverlayAndDescriptionForObjectIfNeeded:(id)object
{
    NSUInteger indexOfView = [self.viewsAtTapPoint indexOfObject:object];
    if (indexOfView != NSNotFound) {
        UIView *view = [self.viewsAtTapPoint objectAtIndex:indexOfView];
        NSValue *key = [NSValue valueWithNonretainedObject:view];
        UIView *outline = [self.outlineViewsForVisibleViews objectForKey:key];
        if (outline) {
            outline.frame = [self frameInLocalCoordinatesForView:view];
        }
    }
    if (object == self.selectedView) {
        // Update the selected view description since we show the frame value there.
        self.explorerToolbar.selectedViewDescription = [FLEXUtility descriptionForView:self.selectedView includingFrame:YES];
        CGRect selectedViewOutlineFrame = [self frameInLocalCoordinatesForView:self.selectedView];
        self.selectedViewOverlay.frame = selectedViewOutlineFrame;
    }
}

- (CGRect)frameInLocalCoordinatesForView:(UIView *)view
{
    // First convert to window coordinates since the view may be in a different window than our view.
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    // Then convert from the window to our view's coordinate space.
    return [self.view convertRect:frameInWindow fromView:nil];
}


#pragma mark - Toolbar Buttons

- (void)setupToolbarActions
{
    [self.explorerToolbar.selectItem addTarget:self action:@selector(selectButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.explorerToolbar.hierarchyItem addTarget:self action:@selector(hierarchyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.explorerToolbar.moveItem addTarget:self action:@selector(moveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.explorerToolbar.globalsItem addTarget:self action:@selector(globalsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.explorerToolbar.closeItem addTarget:self action:@selector(closeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)selectButtonTapped:(FLEXToolbarItem *)sender
{
    if (self.currentMode == FLEXViewHierarchyModeSelect) {
        self.currentMode = FLEXViewHierarchyModeDefault;
    } else {
        self.currentMode = FLEXViewHierarchyModeSelect;
    }
}

- (void)hierarchyButtonTapped:(FLEXToolbarItem *)sender
{
    NSArray *allViews = [self allViewsInHierarchy];
    NSDictionary *depthsForViews = [self hierarchyDepthsForViews:allViews];
    FLEXHierarchyTableViewController *hierarchyTVC = [[FLEXHierarchyTableViewController alloc] initWithViews:allViews viewsAtTap:self.viewsAtTapPoint selectedView:self.selectedView depths:depthsForViews];
    hierarchyTVC.delegate = self;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:hierarchyTVC];
    [[FLEXManager sharedManager] makeKeyAndPresentViewController:navigationController animated:YES completion:nil];
}

- (NSArray *)allViewsInHierarchy
{
    NSMutableArray *allViews = [NSMutableArray array];
    NSArray *windows = [[FLEXManager sharedManager] allWindows];
    
    for (UIWindow *window in windows)
    {
        if (window != self.view.window)
        {
            [allViews addObject:window];
            [allViews addObjectsFromArray:[self allRecursiveSubviewsInView:window]];
        }
    }
    
    return allViews;
}

- (void)moveButtonTapped:(FLEXToolbarItem *)sender
{
    if (self.currentMode == FLEXViewHierarchyModeMove)
    {
        self.currentMode = FLEXViewHierarchyModeDefault;
    }
    else
    {
        self.currentMode = FLEXViewHierarchyModeMove;
    }
}

- (void)globalsButtonTapped:(FLEXToolbarItem *)sender
{
    FLEXInfoTableViewController *globalsViewController = [[FLEXInfoTableViewController alloc] init];
    globalsViewController.delegate = self;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:globalsViewController];
    [[FLEXManager sharedManager] makeKeyAndPresentViewController:navigationController animated:YES completion:nil];
}

- (void)closeButtonTapped:(FLEXToolbarItem *)sender
{
    [self close];
}

- (void)close;
{
    self.currentMode = FLEXViewHierarchyModeDefault;
    
    if ([self.delegate respondsToSelector:@selector(viewControllerDidFinish:)])
    {
        [self.delegate viewControllerDidFinish:self];
    }
    
    //
    // TODO: Close explorer bar
    //
    //[self.delegate explorerViewControllerDidFinish:self];
}

- (void)updateButtonStates
{
    // Move and details only active when an object is selected.
    BOOL hasSelectedObject = self.selectedView != nil;
    self.explorerToolbar.moveItem.enabled = hasSelectedObject;
    self.explorerToolbar.selectItem.selected = self.currentMode == FLEXViewHierarchyModeSelect;
    self.explorerToolbar.moveItem.selected = self.currentMode == FLEXViewHierarchyModeMove;
}


#pragma mark - Toolbar Dragging

- (void)setupToolbarGestures
{
    // Pan gesture for dragging.
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleToolbarPanGesture:)];
    [self.explorerToolbar.dragHandle addGestureRecognizer:panGR];
    
    // Tap gesture for hinting.
    UITapGestureRecognizer *hintTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleToolbarHintTapGesture:)];
    [self.explorerToolbar.dragHandle addGestureRecognizer:hintTapGR];
    
    // Tap gesture for showing additional details
    self.detailsTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleToolbarDetailsTapGesture:)];
    [self.explorerToolbar.selectedViewDescriptionContainer addGestureRecognizer:self.detailsTapGR];
}

- (void)handleToolbarPanGesture:(UIPanGestureRecognizer *)panGR
{
    switch (panGR.state) {
        case UIGestureRecognizerStateBegan:
            self.toolbarFrameBeforeDragging = self.explorerToolbar.frame;
            [self updateToolbarPostionWithDragGesture:panGR];
            break;
            
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateEnded:
            [self updateToolbarPostionWithDragGesture:panGR];
            break;
            
        default:
            break;
    }
}

- (void)updateToolbarPostionWithDragGesture:(UIPanGestureRecognizer *)panGR
{
    CGPoint translation = [panGR translationInView:self.view];
    CGRect newToolbarFrame = self.toolbarFrameBeforeDragging;
    newToolbarFrame.origin.y += translation.y;
    
    CGFloat maxY = CGRectGetMaxY(self.view.bounds) - newToolbarFrame.size.height;
    if (newToolbarFrame.origin.y < 0.0) {
        newToolbarFrame.origin.y = 0.0;
    } else if (newToolbarFrame.origin.y > maxY) {
        newToolbarFrame.origin.y = maxY;
    }
    
    self.explorerToolbar.frame = newToolbarFrame;
}

- (void)handleToolbarHintTapGesture:(UITapGestureRecognizer *)tapGR
{
    // Bounce the toolbar to indicate that it is draggable.
    // TODO: make it bouncier.
    if (tapGR.state == UIGestureRecognizerStateRecognized) {
        CGRect originalToolbarFrame = self.explorerToolbar.frame;
        const NSTimeInterval kHalfwayDuration = 0.2;
        const CGFloat kVerticalOffset = 30.0;
        [UIView animateWithDuration:kHalfwayDuration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGRect newToolbarFrame = self.explorerToolbar.frame;
            newToolbarFrame.origin.y += kVerticalOffset;
            self.explorerToolbar.frame = newToolbarFrame;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:kHalfwayDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                self.explorerToolbar.frame = originalToolbarFrame;
            } completion:nil];
        }];
    }
}

- (void)handleToolbarDetailsTapGesture:(UITapGestureRecognizer *)tapGR
{
    if (tapGR.state == UIGestureRecognizerStateRecognized && self.selectedView) {
        FLEXObjectExplorerViewController *selectedViewExplorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:self.selectedView];
        selectedViewExplorer.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(selectedViewExplorerFinished:)];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:selectedViewExplorer];
        [[FLEXManager sharedManager] makeKeyAndPresentViewController:navigationController animated:YES completion:nil];
    }
}


#pragma mark - View Selection

- (void)handleSelectionTap:(UITapGestureRecognizer *)tapGR
{
    // Only if we're in selection mode
    if (self.currentMode == FLEXViewHierarchyModeSelect && tapGR.state == UIGestureRecognizerStateRecognized) {
        // Note that [tapGR locationInView:nil] is broken in iOS 8, so we have to do a two step conversion to window coordinates.
        // Thanks to @lascorbe for finding this: https://github.com/Flipboard/FLEX/pull/31
        CGPoint tapPointInView = [tapGR locationInView:self.view];
        CGPoint tapPointInWindow = [self.view convertPoint:tapPointInView toView:nil];
        [self updateOutlineViewsForSelectionPoint:tapPointInWindow];
    }
}

- (void)updateOutlineViewsForSelectionPoint:(CGPoint)selectionPointInWindow
{
    [self removeAndClearOutlineViews];
    
    // Include hidden views in the "viewsAtTapPoint" array so we can show them in the hierarchy list.
    self.viewsAtTapPoint = [self viewsAtPoint:selectionPointInWindow skipHiddenViews:NO];
    
    // For outlined views and the selected view, only use visible views.
    // Outlining hidden views adds clutter and makes the selection behavior confusing.
    NSArray *visibleViewsAtTapPoint = [self viewsAtPoint:selectionPointInWindow skipHiddenViews:YES];
    NSMutableDictionary *newOutlineViewsForVisibleViews = [NSMutableDictionary dictionary];
    for (UIView *view in visibleViewsAtTapPoint) {
        UIView *outlineView = [self outlineViewForView:view];
        [self.view addSubview:outlineView];
        NSValue *key = [NSValue valueWithNonretainedObject:view];
        [newOutlineViewsForVisibleViews setObject:outlineView forKey:key];
    }
    self.outlineViewsForVisibleViews = newOutlineViewsForVisibleViews;
    self.selectedView = [self viewForSelectionAtPoint:selectionPointInWindow];
    
    // Make sure the explorer toolbar doesn't end up behind the newly added outline views.
    [self.view bringSubviewToFront:self.explorerToolbar];
    
    [self updateButtonStates];
}

- (UIView *)outlineViewForView:(UIView *)view
{
    CGRect outlineFrame = [self frameInLocalCoordinatesForView:view];
    UIView *outlineView = [[UIView alloc] initWithFrame:outlineFrame];
    outlineView.backgroundColor = [UIColor clearColor];
    outlineView.layer.borderColor = [[FLEXUtility consistentRandomColorForObject:view] CGColor];
    outlineView.layer.borderWidth = 1.0;
    return outlineView;
}

- (void)removeAndClearOutlineViews
{
    for (id key in self.outlineViewsForVisibleViews) {
        UIView *outlineView = self.outlineViewsForVisibleViews[key];
        [outlineView removeFromSuperview];
    }
    self.outlineViewsForVisibleViews = nil;
}

- (NSArray *)viewsAtPoint:(CGPoint)tapPointInWindow skipHiddenViews:(BOOL)skipHidden
{
    NSMutableArray *views = [NSMutableArray array];
    for (UIWindow *window in [[FLEXManager sharedManager] allWindows]) {
        // Don't include the explorer's own window or subviews.
        if (window != self.view.window && [window pointInside:tapPointInWindow withEvent:nil]) {
            [views addObject:window];
            [views addObjectsFromArray:[self recursiveSubviewsAtPoint:tapPointInWindow inView:window skipHiddenViews:skipHidden]];
        }
    }
    return views;
}

- (UIView *)viewForSelectionAtPoint:(CGPoint)tapPointInWindow
{
    // Select in the window that would handle the touch, but don't just use the result of hitTest:withEvent: so we can still select views with interaction disabled.
    // Default to the the application's key window if none of the windows want the touch.
    UIWindow *windowForSelection = [[UIApplication sharedApplication] keyWindow];
    for (UIWindow *window in [[[FLEXManager sharedManager] allWindows] reverseObjectEnumerator])
    {
        // Ignore the explorer's own window.
        if (window != self.view.window) {
            if ([window hitTest:tapPointInWindow withEvent:nil]) {
                windowForSelection = window;
                break;
            }
        }
    }
    
    // Select the deepest visible view at the tap point. This generally corresponds to what the user wants to select.
    return [[self recursiveSubviewsAtPoint:tapPointInWindow inView:windowForSelection skipHiddenViews:YES] lastObject];
}

- (NSArray *)recursiveSubviewsAtPoint:(CGPoint)pointInView inView:(UIView *)view skipHiddenViews:(BOOL)skipHidden
{
    NSMutableArray *subviewsAtPoint = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        BOOL isHidden = subview.hidden || subview.alpha < 0.01;
        if (skipHidden && isHidden) {
            continue;
        }
        
        BOOL subviewContainsPoint = CGRectContainsPoint(subview.frame, pointInView);
        if (subviewContainsPoint) {
            [subviewsAtPoint addObject:subview];
        }
        
        // If this view doesn't clip to its bounds, we need to check its subviews even if it doesn't contain the selection point.
        // They may be visible and contain the selection point.
        if (subviewContainsPoint || !subview.clipsToBounds) {
            CGPoint pointInSubview = [view convertPoint:pointInView toView:subview];
            [subviewsAtPoint addObjectsFromArray:[self recursiveSubviewsAtPoint:pointInSubview inView:subview skipHiddenViews:skipHidden]];
        }
    }
    return subviewsAtPoint;
}

- (NSArray *)allRecursiveSubviewsInView:(UIView *)view
{
    NSMutableArray *subviews = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        [subviews addObject:subview];
        [subviews addObjectsFromArray:[self allRecursiveSubviewsInView:subview]];
    }
    return subviews;
}

- (NSDictionary *)hierarchyDepthsForViews:(NSArray *)views
{
    NSMutableDictionary *hierarchyDepths = [NSMutableDictionary dictionary];
    for (UIView *view in views) {
        NSInteger depth = 0;
        UIView *tryView = view;
        while (tryView.superview) {
            tryView = tryView.superview;
            depth++;
        }
        [hierarchyDepths setObject:@(depth) forKey:[NSValue valueWithNonretainedObject:view]];
    }
    return hierarchyDepths;
}


#pragma mark - Selected View Moving

- (void)handleMovePan:(UIPanGestureRecognizer *)movePanGR
{
    switch (movePanGR.state) {
        case UIGestureRecognizerStateBegan:
            self.selectedViewFrameBeforeDragging = self.selectedView.frame;
            [self updateSelectedViewPositionWithDragGesture:movePanGR];
            break;
            
        case UIGestureRecognizerStateChanged:
        case UIGestureRecognizerStateEnded:
            [self updateSelectedViewPositionWithDragGesture:movePanGR];
            break;
            
        default:
            break;
    }
}

- (void)updateSelectedViewPositionWithDragGesture:(UIPanGestureRecognizer *)movePanGR
{
    CGPoint translation = [movePanGR translationInView:self.selectedView.superview];
    CGRect newSelectedViewFrame = self.selectedViewFrameBeforeDragging;
    newSelectedViewFrame.origin.x = FLEXFloor(newSelectedViewFrame.origin.x + translation.x);
    newSelectedViewFrame.origin.y = FLEXFloor(newSelectedViewFrame.origin.y + translation.y);
    self.selectedView.frame = newSelectedViewFrame;
}


#pragma mark - Touch Handling

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindowCoordinates
{
    BOOL shouldReceiveTouch = NO;
    
    CGPoint pointInLocalCoordinates = [self.view convertPoint:pointInWindowCoordinates fromView:nil];
    
    // Always if it's on the toolbar
    if (CGRectContainsPoint(self.explorerToolbar.frame, pointInLocalCoordinates)) {
        shouldReceiveTouch = YES;
    }
    
    // Always if we're in selection mode
    if (!shouldReceiveTouch && self.currentMode == FLEXViewHierarchyModeSelect) {
        shouldReceiveTouch = YES;
    }
    
    // Always in move mode too
    if (!shouldReceiveTouch && self.currentMode == FLEXViewHierarchyModeMove) {
        shouldReceiveTouch = YES;
    }
    
    // Always if we have a modal presented
    if (!shouldReceiveTouch && self.presentedViewController) {
        shouldReceiveTouch = YES;
    }
    
    return shouldReceiveTouch;
}


#pragma mark - FLEXHierarchyTableViewControllerDelegate

- (void)hierarchyViewController:(FLEXHierarchyTableViewController *)hierarchyViewController didFinishWithSelectedView:(UIView *)selectedView
{
    // Note that we need to wait until the view controller is dismissed to calculated the frame of the outline view.
    // Otherwise the coordinate conversion doesn't give the correct result.
    [[FLEXManager sharedManager] resignKeyAndDismissViewControllerAnimated:YES completion:^{
        // If the selected view is outside of the tapoint array (selected from "Full Hierarchy"),
        // then clear out the tap point array and remove all the outline views.
        if (![self.viewsAtTapPoint containsObject:selectedView]) {
            self.viewsAtTapPoint = nil;
            [self removeAndClearOutlineViews];
        }
        
        // If we now have a selected view and we didn't have one previously, go to "select" mode.
        if (self.currentMode == FLEXViewHierarchyModeDefault && selectedView) {
            self.currentMode = FLEXViewHierarchyModeSelect;
        }
        
        // The selected view setter will also update the selected view overlay appropriately.
        self.selectedView = selectedView;
    }];
}


#pragma mark - FLEXViewControllerDelegate

- (void)viewControllerDidFinish:(UIViewController *)viewController
{
    [[FLEXManager sharedManager] resignKeyAndDismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - FLEXObjectExplorerViewController Done Action

- (void)selectedViewExplorerFinished:(id)sender
{
    [[FLEXManager sharedManager] resignKeyAndDismissViewControllerAnimated:YES completion:nil];
}

@end
