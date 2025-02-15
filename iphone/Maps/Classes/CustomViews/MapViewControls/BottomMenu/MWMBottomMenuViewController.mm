#import "BookmarksRootVC.h"
#import "Common.h"
#import "MapsAppDelegate.h"
#import "MapViewController.h"
#import "MWMActivityViewController.h"
#import "MWMBottomMenuCollectionViewCell.h"
#import "MWMBottomMenuLayout.h"
#import "MWMBottomMenuView.h"
#import "MWMBottomMenuViewController.h"
#import "MWMMapViewControlsManager.h"
#import "MWMSearchManager.h"
#import "SettingsAndMoreVC.h"
#import "UIColor+MapsMeColor.h"
#import "UIKitCategories.h"

#import "3party/Alohalytics/src/alohalytics_objc.h"

#include "Framework.h"

extern NSString * const kAlohalyticsTapEventKey;
extern NSString * const kSearchStateWillChangeNotification;
extern NSString * const kSearchStateKey;

static NSString * const kCollectionCellPortrait = @"MWMBottomMenuCollectionViewPortraitCell";
static NSString * const kCollectionCelllandscape = @"MWMBottomMenuCollectionViewLandscapeCell";

static CGFloat const kLayoutThreshold = 420.0;

typedef NS_ENUM(NSUInteger, MWMBottomMenuViewCell)
{
  MWMBottomMenuViewCellDownload,
  MWMBottomMenuViewCellSettings,
  MWMBottomMenuViewCellShare,
  MWMBottomMenuViewCellCount
};

@interface MWMBottomMenuViewController ()<UICollectionViewDataSource, UICollectionViewDelegate>

@property(weak, nonatomic) MapViewController * controller;
@property(weak, nonatomic) IBOutlet UICollectionView * buttonsCollectionView;

@property(weak, nonatomic) IBOutlet UIButton * locationButton;
@property(weak, nonatomic) IBOutlet UICollectionView * additionalButtons;
@property(weak, nonatomic) IBOutlet UILabel * streetLabel;

@property(weak, nonatomic) id<MWMBottomMenuControllerProtocol> delegate;

@property(nonatomic) BOOL searchIsActive;

@property(nonatomic) SolidTouchView * dimBackground;

@property(nonatomic) MWMBottomMenuState restoreState;

@property(nonatomic) int locationListenerSlot;

@end

@implementation MWMBottomMenuViewController

- (instancetype)initWithParentController:(MapViewController *)controller
                                delegate:(id<MWMBottomMenuControllerProtocol>)delegate
{
  self = [super init];
  if (self)
  {
    _controller = controller;
    _delegate = delegate;
    [controller addChildViewController:self];
    MWMBottomMenuView * view = (MWMBottomMenuView *)self.view;
    [controller.view addSubview:view];
    view.maxY = controller.view.height;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchStateWillChange:)
                                                 name:kSearchStateWillChangeNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setupCollectionView];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self configLocationListener];
  [self onLocationStateModeChanged:GetFramework().GetLocationState()->GetMode()];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  GetFramework().GetLocationState()->RemoveStateModeListener(self.locationListenerSlot);
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
  [self.additionalButtons reloadData];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [self.additionalButtons reloadData];
}

#pragma mark - Routing state

- (void)setStreetName:(NSString *)streetName
{
  self.state = MWMBottomMenuStateText;
  self.streetLabel.text = streetName;
}

- (void)setPlanning
{
  if (IPAD)
    return;
  self.state = MWMBottomMenuStatePlanning;
}

- (void)setGo
{
  if (IPAD)
    return;
  self.state = MWMBottomMenuStateGo;
}

#pragma mark - Location button

- (void)configLocationListener
{
  typedef void (*LocationStateModeFnT)(id, SEL, location::State::Mode);
  SEL locationStateModeSelector = @selector(onLocationStateModeChanged:);
  LocationStateModeFnT locationStateModeFn =
      (LocationStateModeFnT)[self methodForSelector:locationStateModeSelector];

  self.locationListenerSlot = GetFramework().GetLocationState()->AddStateModeListener(
      bind(locationStateModeFn, self, locationStateModeSelector, _1));
}

- (void)onLocationStateModeChanged:(location::State::Mode)state
{
  UIButton * locBtn = self.locationButton;
  [locBtn.imageView.layer removeAllAnimations];
  switch (state)
  {
  case location::State::Mode::UnknownPosition:
    [locBtn setImage:[UIImage imageNamed:@"ic_menu_location_off_mode_light"]
            forState:UIControlStateNormal];
    break;
  case location::State::Mode::PendingPosition:
  {
    [locBtn setImage:[UIImage imageNamed:@"ic_menu_location_pending"]
            forState:UIControlStateNormal];
    CABasicAnimation * rotation;
    rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.duration = kDefaultAnimationDuration;
    rotation.toValue = @(M_PI * 2.0 * rotation.duration);
    rotation.cumulative = YES;
    rotation.repeatCount = MAXFLOAT;
    [locBtn.imageView.layer addAnimation:rotation forKey:@"locationImage"];
    break;
  }
  case location::State::Mode::NotFollow:
    [locBtn setImage:[UIImage imageNamed:@"ic_menu_location_get_position"]
            forState:UIControlStateNormal];
    break;
  case location::State::Mode::Follow:
    [locBtn setImage:[UIImage imageNamed:@"ic_menu_location_follow"] forState:UIControlStateNormal];
    break;
  case location::State::Mode::RotateAndFollow:
    UIButton * btn = self.locationButton;
    NSUInteger const morphImagesCount = 6;
    NSUInteger const startValue = 1;
    NSUInteger const endValue = morphImagesCount + 1;
    NSMutableArray * morphImages = [NSMutableArray arrayWithCapacity:morphImagesCount];
    for (NSUInteger i = startValue, j = 0; i != endValue; i++, j++)
      morphImages[j] = [UIImage imageNamed:[@"ic_follow_mode_light_" stringByAppendingString:@(i).stringValue]];
    btn.imageView.animationImages = morphImages;
    btn.imageView.animationRepeatCount = 1;
    btn.imageView.image = morphImages.lastObject;
    [btn.imageView startAnimating];
    break;
  }
}

#pragma mark - Notifications

- (void)searchStateWillChange:(NSNotification *)notification
{
  MWMSearchManagerState state =
      MWMSearchManagerState([[notification userInfo][kSearchStateKey] unsignedIntegerValue]);
  self.searchIsActive = state != MWMSearchManagerStateHidden;
}

#pragma mark - Setup

- (void)setupCollectionView
{
  [self.buttonsCollectionView registerNib:[UINib nibWithNibName:kCollectionCellPortrait bundle:nil]
               forCellWithReuseIdentifier:kCollectionCellPortrait];
  [self.buttonsCollectionView registerNib:[UINib nibWithNibName:kCollectionCelllandscape bundle:nil]
               forCellWithReuseIdentifier:kCollectionCelllandscape];
  MWMBottomMenuLayout * cvLayout =
      (MWMBottomMenuLayout *)self.buttonsCollectionView.collectionViewLayout;
  cvLayout.buttonsCount = MWMBottomMenuViewCellCount;
  cvLayout.layoutThreshold = kLayoutThreshold;
  ((MWMBottomMenuView *)self.view).layoutThreshold = kLayoutThreshold;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
  return MWMBottomMenuViewCellCount;
}

- (nonnull UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView
                          cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  BOOL const isWideMenu = self.view.width > kLayoutThreshold;
  MWMBottomMenuCollectionViewCell * cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:isWideMenu ? kCollectionCelllandscape
                                                                        : kCollectionCellPortrait
                                                forIndexPath:indexPath];
  switch (indexPath.item)
  {
  case MWMBottomMenuViewCellDownload:
  {
    NSUInteger const badgeCount =
        GetFramework().GetCountryTree().GetActiveMapLayout().GetOutOfDateCount();
    [cell configureWithIconName:@"ic_menu_download"
                          label:L(@"download_maps")
                     badgeCount:badgeCount];
  }
  break;
  case MWMBottomMenuViewCellSettings:
    [cell configureWithIconName:@"ic_menu_settings" label:L(@"settings") badgeCount:0];
    break;
  case MWMBottomMenuViewCellShare:
    [cell configureWithIconName:@"ic_menu_share" label:L(@"share_my_location") badgeCount:0];
    break;
  case MWMBottomMenuViewCellCount:
    break;
  }
  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(nonnull UICollectionView *)collectionView
    didSelectItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  switch (indexPath.item)
  {
  case MWMBottomMenuViewCellDownload:
    [self menuActionDownloadMaps];
    break;
  case MWMBottomMenuViewCellSettings:
    [self menuActionOpenSettings];
    break;
  case MWMBottomMenuViewCellShare:
    [self menuActionShareLocation];
    break;
  case MWMBottomMenuViewCellCount:
    break;
  }
}

- (void)collectionView:(nonnull UICollectionView *)collectionView
    didHighlightItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  MWMBottomMenuCollectionViewCell * cell =
      (MWMBottomMenuCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
  [cell highlighted:YES];
}

- (void)collectionView:(nonnull UICollectionView *)collectionView
    didUnhighlightItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  MWMBottomMenuCollectionViewCell * cell =
      (MWMBottomMenuCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
  [cell highlighted:NO];
}

#pragma mark - Buttons actions

- (void)menuActionDownloadMaps
{
  self.state = MWMBottomMenuStateInactive;
  [self.delegate actionDownloadMaps];
}

- (void)menuActionOpenSettings
{
  self.state = MWMBottomMenuStateInactive;
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"settingsAndMore"];
  SettingsAndMoreVC * const vc = [[SettingsAndMoreVC alloc] initWithStyle:UITableViewStyleGrouped];
  [self.controller.navigationController pushViewController:vc animated:YES];
}

- (void)menuActionShareLocation
{
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"share@"];
  CLLocation * location = [MapsAppDelegate theApp].m_locationManager.lastLocation;
  if (!location)
  {
    [[[UIAlertView alloc] initWithTitle:L(@"unknown_current_position")
                                message:nil
                               delegate:nil
                      cancelButtonTitle:L(@"ok")
                      otherButtonTitles:nil] show];
    return;
  }
  CLLocationCoordinate2D const coord = location.coordinate;
  NSIndexPath * cellIndex = [NSIndexPath indexPathForItem:MWMBottomMenuViewCellShare inSection:0];
  MWMBottomMenuCollectionViewCell * cell =
      (MWMBottomMenuCollectionViewCell *)[self.additionalButtons cellForItemAtIndexPath:cellIndex];
  MWMActivityViewController * shareVC =
      [MWMActivityViewController shareControllerForLocationTitle:nil location:coord myPosition:YES];
  [shareVC presentInParentViewController:self.controller anchorView:cell.icon];
}

- (IBAction)locationButtonTouchUpInside:(UIButton *)sender
{
  GetFramework().GetLocationState()->SwitchToNextMode();
}

- (IBAction)point2PointButtonTouchUpInside:(UIButton *)sender
{
}

- (IBAction)searchButtonTouchUpInside:(UIButton *)sender
{
  self.state = MWMBottomMenuStateInactive;
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"search"];
  self.controller.controlsManager.searchHidden = self.searchIsActive;
}

- (IBAction)bookmarksButtonTouchUpInside:(UIButton *)sender
{
  self.state = MWMBottomMenuStateInactive;
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"bookmarks"];
  BookmarksRootVC * const vc = [[BookmarksRootVC alloc] init];
  [self.controller.navigationController pushViewController:vc animated:YES];
}

- (IBAction)menuButtonTouchUpInside:(UIButton *)sender
{
  switch (self.state)
  {
  case MWMBottomMenuStateHidden:
    NSAssert(false, @"Incorrect state");
    break;
  case MWMBottomMenuStateInactive:
  case MWMBottomMenuStatePlanning:
  case MWMBottomMenuStateGo:
  case MWMBottomMenuStateText:
    self.state = MWMBottomMenuStateActive;
    break;
  case MWMBottomMenuStateActive:
    self.state = self.restoreState;
    break;
  case MWMBottomMenuStateCompact:
    [self.delegate closeInfoScreens];
    break;
  }
}
- (IBAction)goButtonTouchUpInside:(UIButton *)sender
{
}

- (void)dimBackgroundTap
{
  self.state = self.restoreState;
}

- (void)toggleDimBackgroundVisible:(BOOL)visible
{
  if (visible)
    [self.controller.view insertSubview:self.dimBackground belowSubview:self.view];
  self.dimBackground.alpha = visible ? 0.0 : 0.8;
  [UIView animateWithDuration:kDefaultAnimationDuration animations:^
  {
    self.dimBackground.alpha = visible ? 0.8 : 0.0;
  }
  completion:^(BOOL finished)
  {
    if (!visible)
    {
      [self.dimBackground removeFromSuperview];
      self.dimBackground = nil;
    }
  }];
}

#pragma mark - Properties

- (SolidTouchView *)dimBackground
{
  if (!_dimBackground)
  {
    _dimBackground = [[SolidTouchView alloc] initWithFrame:self.controller.view.bounds];
    _dimBackground.backgroundColor = [UIColor fadeBackground];
    _dimBackground.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UITapGestureRecognizer * tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimBackgroundTap)];
    [_dimBackground addGestureRecognizer:tap];
  }
  return _dimBackground;
}

- (void)setState:(MWMBottomMenuState)state
{
  [self toggleDimBackgroundVisible:state == MWMBottomMenuStateActive];
  MWMBottomMenuView * view = (MWMBottomMenuView *)self.view;
  if (view.state == MWMBottomMenuStateCompact &&
      (state == MWMBottomMenuStatePlanning || state == MWMBottomMenuStateGo ||
       state == MWMBottomMenuStateText))
    self.restoreState = state;
  else
    view.state = state;
}

- (MWMBottomMenuState)state
{
  return ((MWMBottomMenuView *)self.view).state;
}

- (void)setRestoreState:(MWMBottomMenuState)restoreState
{
  ((MWMBottomMenuView *)self.view).restoreState = restoreState;
}

- (MWMBottomMenuState)restoreState
{
  return ((MWMBottomMenuView *)self.view).restoreState;
}

- (void)setLeftBound:(CGFloat)leftBound
{
  ((MWMBottomMenuView *)self.view).leftBound = leftBound;
}

- (CGFloat)leftBound
{
  return ((MWMBottomMenuView *)self.view).leftBound;
}

- (void)setSearchIsActive:(BOOL)searchIsActive
{
  ((MWMBottomMenuView *)self.view).searchIsActive = searchIsActive;
}

- (BOOL)searchIsActive
{
  return ((MWMBottomMenuView *)self.view).searchIsActive;
}

@end
