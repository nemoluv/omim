#import "MWMBasePlacePageView.h"
#import "MWMBookmarkColorViewController.h"
#import "MWMBookmarkDescriptionViewController.h"
#import "MWMDirectionView.h"
#import "MWMPlacePage.h"
#import "MWMPlacePageActionBar.h"
#import "MWMPlacePageEntity.h"
#import "MWMPlacePageViewManager.h"
#import "SelectSetVC.h"

#import "../../3party/Alohalytics/src/alohalytics_objc.h"

static NSString * const kPlacePageNibIdentifier = @"PlacePageView";
extern NSString * const kAlohalyticsTapEventKey;
static NSString * const kPlacePageViewCenterKeyPath = @"center";

@interface MWMPlacePage ()

@property (weak, nonatomic, readwrite) MWMPlacePageViewManager * manager;

@end

@implementation MWMPlacePage

- (instancetype)initWithManager:(MWMPlacePageViewManager *)manager
{
  self = [super init];
  if (self)
  {
    [[NSBundle mainBundle] loadNibNamed:kPlacePageNibIdentifier owner:self options:nil];
    self.manager = manager;
    if (!IPAD)
    {
      [self.extendedPlacePageView addObserver:self
                                   forKeyPath:kPlacePageViewCenterKeyPath
                                      options:NSKeyValueObservingOptionNew
                                      context:nullptr];
    }
  }
  return self;
}

- (void)dealloc
{
  if (!IPAD)
  {
    [self.extendedPlacePageView removeObserver:self forKeyPath:kPlacePageViewCenterKeyPath];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if ([self.extendedPlacePageView isEqual:object] &&
      [keyPath isEqualToString:kPlacePageViewCenterKeyPath])
    [self.manager dragPlacePage:self.extendedPlacePageView.frame];
}

- (void)configure
{
  MWMPlacePageEntity * entity = self.manager.entity;
  [self.basePlacePageView configureWithEntity:entity];
  [self.actionBar configureWithPlacePage:self];
}

- (void)show
{
  // Should override this method if you want to show place page with custom animation.
}

- (void)hide
{
  // Should override this method if you want to hide place page with custom animation.
}

- (void)dismiss
{
  [self.extendedPlacePageView removeFromSuperview];
  [self.actionBar removeFromSuperview];
  self.actionBar = nil;
}

#pragma mark - Actions
- (void)apiBack
{
  [self.manager apiBack];
}

- (void)addBookmark
{
  [self.basePlacePageView addBookmark];
  [self.manager addBookmark];
}

- (void)removeBookmark
{
  [self.basePlacePageView removeBookmark];
  [self.manager removeBookmark];
  self.keyboardHeight = 0.;
}

- (void)share
{
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppShare"];
  [self.manager share];
}

- (void)route
{
  [Alohalytics logEvent:kAlohalyticsTapEventKey withValue:@"ppRoute"];
  [self.manager buildRoute];
}

- (void)addPlacePageShadowToView:(UIView *)view offset:(CGSize)offset
{
  CALayer * layer = view.layer;
  layer.masksToBounds = NO;
  layer.shadowColor = UIColor.blackColor.CGColor;
  layer.shadowRadius = 4.;
  layer.shadowOpacity = 0.24f;
  layer.shadowOffset = offset;
  layer.shouldRasterize = YES;
  layer.rasterizationScale = [[UIScreen mainScreen] scale];
}

- (void)setDirectionArrowTransform:(CGAffineTransform)transform
{
  self.basePlacePageView.directionArrow.transform = transform;
}

- (void)setDistance:(NSString *)distance
{
  self.basePlacePageView.distanceLabel.text = distance;
}

- (void)updateMyPositionStatus:(NSString *)status
{
  [self.basePlacePageView updateAndLayoutMyPositionSpeedAndAltitude:status];
}

- (void)changeBookmarkCategory
{
  MWMPlacePageViewManager * manager = self.manager;
  SelectSetVC * vc = [[SelectSetVC alloc] initWithPlacePageManager:manager];
  [manager.ownerViewController.navigationController pushViewController:vc animated:YES];
}

- (void)changeBookmarkColor
{
  MWMBookmarkColorViewController * controller = [[MWMBookmarkColorViewController alloc] initWithNibName:[MWMBookmarkColorViewController className] bundle:nil];
  controller.placePageManager = self.manager;
  [self.manager.ownerViewController.navigationController pushViewController:controller animated:YES];
}

- (void)changeBookmarkDescription
{
  MWMBookmarkDescriptionViewController * viewController = [[MWMBookmarkDescriptionViewController alloc] initWithPlacePageManager:self.manager];
  [self.manager.ownerViewController.navigationController pushViewController:viewController animated:YES];
}

- (void)reloadBookmark
{
  [self.basePlacePageView reloadBookmarkCell];
}

- (void)willStartEditingBookmarkTitle:(CGFloat)keyboardHeight
{
  self.keyboardHeight = keyboardHeight;
}

- (void)willFinishEditingBookmarkTitle:(NSString *)title
{
  self.basePlacePageView.titleLabel.text = title;
  [self.basePlacePageView layoutIfNeeded];
  self.keyboardHeight = 0.;
}

- (IBAction)didTap:(UITapGestureRecognizer *)sender
{
// This method should be ovverriden if you want to process custom tap.
}

- (IBAction)didPan:(UIPanGestureRecognizer *)sender
{
  // This method should be ovverriden if you want to process custom pan.
}

#pragma mark - Properties

- (MWMPlacePageActionBar *)actionBar
{
  if (!_actionBar)
    _actionBar = [MWMPlacePageActionBar actionBarForPlacePage:self];
  return _actionBar;
}

@end
