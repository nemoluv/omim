#import "Common.h"
#import "LocationManager.h"
#import "MapsAppDelegate.h"
#import "MWMSearchCommonCell.h"
#import "UIColor+MapsMeColor.h"
#import "UIFont+MapsMeFonts.h"

#include "indexer/mercator.hpp"
#include "platform/measurement_utils.hpp"

static NSDictionary * const kSelectedAttributes = @{
  NSForegroundColorAttributeName : UIColor.blackPrimaryText,
  NSFontAttributeName : UIFont.bold17
};

static NSDictionary * const kUnselectedAttributes = @{
  NSForegroundColorAttributeName : UIColor.blackPrimaryText,
  NSFontAttributeName : UIFont.regular17
};

@interface MWMSearchCommonCell ()

@property (weak, nonatomic) IBOutlet UILabel * typeLabel;
@property (weak, nonatomic) IBOutlet UIView * infoView;
@property (weak, nonatomic) IBOutlet UILabel * infoLabel;
@property (weak, nonatomic) IBOutlet UIView * infoRatingView;
@property (nonatomic) IBOutletCollection(UIImageView) NSArray * infoRatingStars;
@property (weak, nonatomic) IBOutlet UILabel * locationLabel;
@property (weak, nonatomic) IBOutlet UILabel * distanceLabel;
@property (weak, nonatomic) IBOutlet UIView * closedView;

@end

@implementation MWMSearchCommonCell

- (void)config:(search::Result &)result forHeight:(BOOL)forHeight
{
  [super config:result];
  self.typeLabel.text = @(result.GetFeatureType()).capitalizedString;
  self.locationLabel.text = @(result.GetRegionString());
  [self.locationLabel sizeToFit];

  if (!forHeight)
  {
    NSUInteger const starsCount = result.GetStarsCount();
    NSString * cuisine = @(result.GetCuisine());
    if (starsCount > 0)
      [self setInfoRating:starsCount];
    else if (cuisine.length > 0)
      [self setInfoText:cuisine.capitalizedString];
    else
      [self clearInfo];

    self.closedView.hidden = !result.IsClosed();
    if (result.HasPoint())
    {
      string distanceStr;
      double lat, lon;
      LocationManager * locationManager = MapsAppDelegate.theApp.m_locationManager;
      if ([locationManager getLat:lat Lon:lon])
      {
        m2::PointD const mercLoc = MercatorBounds::FromLatLon(lat, lon);
        double const dist = MercatorBounds::DistanceOnEarth(mercLoc, result.GetFeatureCenter());
        MeasurementUtils::FormatDistance(dist, distanceStr);
      }
      self.distanceLabel.text = @(distanceStr.c_str());
    }
  }
  if (isIOSVersionLessThan(8))
    [self layoutIfNeeded];
}

- (void)setInfoText:(NSString *)infoText
{
  self.infoView.hidden = NO;
  self.infoLabel.hidden = NO;
  self.infoRatingView.hidden = YES;
  self.infoLabel.text = infoText;
}

- (void)setInfoRating:(NSUInteger)infoRating
{
  self.infoView.hidden = NO;
  self.infoRatingView.hidden = NO;
  self.infoLabel.hidden = YES;
  [self.infoRatingStars enumerateObjectsUsingBlock:^(UIImageView * star, NSUInteger idx, BOOL *stop)
  {
    star.highlighted = star.tag <= infoRating;
  }];
}

- (void)clearInfo
{
  self.infoView.hidden = YES;
}

- (NSDictionary *)selectedTitleAttributes
{
  return kSelectedAttributes;
}

- (NSDictionary *)unselectedTitleAttributes
{
  return kUnselectedAttributes;
}

+ (CGFloat)defaultCellHeight
{
  return 80.0;
}

- (CGFloat)cellHeight
{
  return ceil([self.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height);
}

#pragma mark - Properties

- (void)setIsLightTheme:(BOOL)isLightTheme
{
  _isLightTheme = isLightTheme;
  UIImage * star = nil;
  UIImage * starHighlighted = nil;
  if (isLightTheme)
  {
    star = [UIImage imageNamed:@"hotel_star_off_light"];
    starHighlighted = [UIImage imageNamed:@"hotel_star_on_light"];
  }
  else
  {
    star = [UIImage imageNamed:@"hotel_star_off_dark"];
    starHighlighted = [UIImage imageNamed:@"hotel_star_on_dark"];
  }
  [self.infoRatingStars enumerateObjectsUsingBlock:^(UIImageView * starView, NSUInteger idx, BOOL * stop)
  {
    [starView setImage:star];
    [starView setHighlightedImage:starHighlighted];
  }];
}

@end
