//
//  TTSwitch.m
//  TTSwitch
//
//  Created by Scott Penrose on 12/3/12.
//  Copyright (c) 2012 Two Toasters. All rights reserved.
//

#import "TTSwitch.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kTTSwitchAnimationDuration = 0.25;

@interface TTSwitch ()

@property (nonatomic, strong) UIImageView *trackImageView;
@property (nonatomic, strong) UIImageView *overlayImageView;
@property (nonatomic, strong) UIImageView *thumbImageView;

@property (nonatomic, strong) UIView *maskedTrackView;
@property (nonatomic, strong) UIView *maskedThumbView;

@property (nonatomic, strong) CALayer *trackMaskLayer;
@property (nonatomic, strong) UIImage *onTrackMaskImage;
@property (nonatomic, strong) UIImage *offTrackMaskImage;

@property (nonatomic, strong, readwrite) UILabel *onLabel;
@property (nonatomic, strong, readwrite) UILabel *offLabel;

/**
 A Boolean value that determines the off/on state of the switch.
 @param on the off/on state
 @param animated When changing the state of the switch should the switch animate to its new state
 @param sendActions Allows for changing of the switch without calling the change handler block.
 */
- (void)setOn:(BOOL)on animated:(BOOL)animated sendActions:(BOOL)sendActions;

@end

@implementation TTSwitch

#pragma mark - Init/dealloc

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _maskInLockPosition = @YES;
    
    _maskedTrackView = [[UIView alloc] initWithFrame:self.bounds];
    _maskedThumbView = [[UIView alloc] initWithFrame:self.bounds];
    
    _trackImageView = [[UIImageView alloc] init];
    _overlayImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    
    _thumbImageView = [[UIImageView alloc] init];
    [_thumbImageView setUserInteractionEnabled:YES];
    
    [_maskedTrackView addSubview:_trackImageView];
    [_maskedThumbView addSubview:_thumbImageView];
    

    _onLabel = [[UILabel alloc] initWithFrame:(CGRect) {CGPointZero, self.bounds.size }];
    _offLabel = [[UILabel alloc] initWithFrame:(CGRect) {CGPointZero, self.bounds.size }];
    
    _onLabel.backgroundColor = _offLabel.backgroundColor = [UIColor clearColor];
    _onLabel.textAlignment = _offLabel.textAlignment = UITextAlignmentCenter;
    
    _onLabel.text = @"AN";
    _offLabel.text = @"AUS";
    
    
    [_trackImageView addSubview:_onLabel];
    [_trackImageView addSubview:_offLabel];
    
    [self addSubview:_maskedTrackView];
    [self addSubview:_overlayImageView];
    [self addSubview:_maskedThumbView];
    
    // Track Mask Layers
    _trackMaskLayer = [CALayer layer];
    _trackMaskLayer.frame = self.bounds;
    
    UIPanGestureRecognizer *thumbPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleThumbPanGesture:)];
    [thumbPanGestureRecognizer setMinimumNumberOfTouches:1];
    [_thumbImageView addGestureRecognizer:thumbPanGestureRecognizer];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self addGestureRecognizer:tapGestureRecognizer];
    
    self.clipsToBounds = NO;
    self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
    self.layer.shouldRasterize = YES;
}

#pragma mark - Public interface

- (void)setTrackImage:(UIImage *)trackImage
{
    if (_trackImage != trackImage) {
        _trackImage = trackImage;
        [_trackImageView setImage:_trackImage];
        [_trackImageView setFrame:(CGRect){ CGPointZero, _trackImage.size }];
        [self refreshLabelFrames];
        

    }
}

- (void)setOverlayImage:(UIImage *)overlayImage
{
    if (_overlayImage != overlayImage) {
        _overlayImage = overlayImage;
        [_overlayImageView setImage:_overlayImage];
    }
}

- (void)setTrackMaskImage:(UIImage *)trackMaskImage
{
    if (_trackMaskImage != trackMaskImage) {
        _trackMaskImage = trackMaskImage;
        
        _trackMaskLayer.contents = (id)[_trackMaskImage CGImage];
        [self createMasksForLockPosition];
        
        self.maskedTrackView.layer.mask = _trackMaskLayer;
    }
}

- (void)setThumbMaskImage:(UIImage *)thumbMaskImage
{
    if (_thumbMaskImage != thumbMaskImage) {
        _thumbMaskImage = thumbMaskImage;
        
        if (_thumbMaskImage) {
            CALayer *thumbMaskLayer = [CALayer layer];
            thumbMaskLayer.frame = self.bounds;
            thumbMaskLayer.contents = (id)[_thumbMaskImage CGImage];
            self.maskedThumbView.layer.mask = thumbMaskLayer;
        } else {
            // remove mask if nil
            self.maskedThumbView = [[UIView alloc] initWithFrame:self.bounds];
        }
    }
}

- (void)setThumbImage:(UIImage *)thumbImage
{
    if (_thumbImage != thumbImage) {
        _thumbImage = thumbImage;
        [_thumbImageView setImage:_thumbImage];
        [_thumbImageView setFrame:(CGRect){ { 0.0f, self.thumbOffsetY }, _thumbImage.size }];
        [self createMasksForLockPosition];
        [self updateThumbPositionAnimated:NO];
    }
}

- (void)setThumbInsetX:(CGFloat)thumbInsetX
{
    _thumbInsetX = floorf(thumbInsetX);
    [self createMasksForLockPosition];
    [self updateThumbPositionAnimated:NO];
}

- (void)setThumbOffsetY:(CGFloat)thumbOffsetY
{
    _thumbOffsetY = floorf(thumbOffsetY);
    [self.thumbImageView setFrame:(CGRect){ { 0.0f, _thumbOffsetY }, self.thumbImageView.image.size }];
    [self updateThumbPositionAnimated:NO];
}

- (void)setMaskInLockPosition:(NSNumber *)maskInLockPosition
{
    if (_maskInLockPosition == maskInLockPosition) return;

    _maskInLockPosition = maskInLockPosition;
    [self standardMask];
    [self updateThumbPositionAnimated:NO];
}

- (void)setOn:(BOOL)on
{
    [self setOn:on animated:NO sendActions:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated
{
    [self setOn:on animated:animated sendActions:NO];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated sendActions:(BOOL)sendActions
{
    [self standardMask];
    
    if (_on != on) {
        _on = on;
        
        if (sendActions) {
            if (self.changeHandler) {
                self.changeHandler(_on);
            }
            
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
    
    [self updateThumbPositionAnimated:animated];
}

#pragma mark - Helpers

- (CGFloat)valueAtThumbPosition
{
    CGFloat range = self.frame.size.width - 2 * self.thumbInsetX - self.thumbImageView.frame.size.width;
    CGFloat locationInRange = self.thumbImageView.frame.origin.x - self.thumbInsetX;
    
    if (range == 0) {
        NSLog(@"TTSwitch can't get value at thumb position because you are going to have a bad time dividing by zero.");
        return 0.0f;
    }
    
    return locationInRange / range;
}

- (void)updateThumbPositionAnimated:(BOOL)animated
{
    CGFloat newThumbXCenter = floorf((self.thumbImageView.frame.size.width / 2) + self.thumbInsetX);
    if (_on) {
        CGFloat range = floorf(self.frame.size.width - 2 * self.thumbInsetX - self.thumbImageView.frame.size.width);
        newThumbXCenter += range;
    }
    
    [self thumbImageHighlighted:NO];
    
    if (animated) {
        CGFloat distanceOfTravel = fabsf((_on ? 1.0f : 0.0f) - [self valueAtThumbPosition]);
        CGFloat animationDuration = kTTSwitchAnimationDuration * distanceOfTravel;
        
        [UIView animateWithDuration:animationDuration animations:^{
            [self.thumbImageView setCenter:(CGPoint){ newThumbXCenter, self.thumbImageView.center.y }];
            [self.trackImageView setCenter:(CGPoint){ newThumbXCenter, self.trackImageView.center.y }];
        } completion:^(BOOL finished) {
            [self maskInLockPosition];
        }];
    }
    else {
        [self.thumbImageView setCenter:(CGPoint){ newThumbXCenter, self.thumbImageView.center.y }];
        [self.trackImageView setCenter:(CGPoint){ newThumbXCenter, self.trackImageView.center.y }];
        [self maskInLockPosition];
    }
}

- (void)thumbImageHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        self.thumbImageView.image = self.thumbHighlightImage;
    } else {
        self.thumbImageView.image = self.thumbImage;
    }
}

- (void)refreshLabelFrames
{
    CGFloat halfWidth = ceilf(CGRectGetWidth(_trackImageView.frame)/2.0f);
    CGFloat halfThumbWidth = ceilf(CGRectGetWidth(_thumbImageView.frame)/2.0f);
    CGSize labelSize =  self.bounds.size;
    labelSize.width -= CGRectGetWidth(_thumbImageView.frame);
    
    _onLabel.frame = (CGRect) { CGPointMake(halfWidth-halfThumbWidth-labelSize.width, .0f), labelSize };
    _offLabel.frame = (CGRect) { CGPointMake(halfWidth+halfThumbWidth, .0f), labelSize };
}

#pragma mark - UIGestureRecognizer

- (void)handleThumbPanGesture:(UIPanGestureRecognizer *)gesture
{
    UIView *thumbImageView = [gesture view];
    
    if ([gesture state] == UIGestureRecognizerStateBegan) {
        [self standardMask];
        [self thumbImageHighlighted:YES];
    }
    
    if ([gesture state] == UIGestureRecognizerStateBegan || [gesture state] == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:[thumbImageView superview]];
        
        // Don't move past start or end
        CGFloat newX = floorf(thumbImageView.frame.origin.x + translation.x);
        CGFloat leftBoundary = self.thumbInsetX;
        CGFloat range = floorf(self.frame.size.width - 2 * self.thumbInsetX - self.thumbImageView.frame.size.width);
        CGFloat rightBoundary = leftBoundary + range;
        newX = floorf(MAX(leftBoundary, MIN(rightBoundary, newX)) + (thumbImageView.frame.size.width / 2));
        
        [thumbImageView setCenter:(CGPoint){ newX, [thumbImageView center].y }];
        [self.trackImageView setCenter:(CGPoint){ newX, self.trackImageView.center.y }];
        [gesture setTranslation:CGPointZero inView:[thumbImageView superview]];
        [gesture setTranslation:CGPointZero inView:[self.trackImageView superview]];
    }
    else if ([gesture state] == UIGestureRecognizerStateEnded) {
        [self setOn:(0.5f < self.valueAtThumbPosition) animated:YES sendActions:YES];
    }
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture
{
    [self setOn:!_on animated:YES sendActions:YES];
}

#pragma mark - Masking

- (void)createMasksForLockPosition
{
    CGFloat thumbCenterX = floorf((self.thumbImageView.frame.size.width / 2) + self.thumbInsetX); // Don't use self.thumbImageView.center.x because it might not be in correct position
    
    self.offTrackMaskImage = [self cropImage:self.trackMaskImage rect:(CGRect){ { thumbCenterX, 0 }, { (self.trackMaskImage.size.width - thumbCenterX), self.trackMaskImage.size.height } }];
    self.onTrackMaskImage = [self cropImage:self.trackMaskImage rect:(CGRect){ CGPointZero, { self.trackMaskImage.size.width - thumbCenterX, self.trackMaskImage.size.height } }];
}

- (void)maskInLockPosition
{
    if (! [self.shouldMaskInLockPosition boolValue]) return;
    
    [CATransaction setAnimationDuration:0.0f];
    if (self.isOn) {
        _trackMaskLayer.contents = (id)self.onTrackMaskImage.CGImage;
        _trackMaskLayer.frame = (CGRect){ { 0.0f, 0.0f }, self.onTrackMaskImage.size};
    } else {
        _trackMaskLayer.contents = (id)self.offTrackMaskImage.CGImage;
        _trackMaskLayer.frame = (CGRect){ { self.thumbImageView.center.x, 0.0f }, self.offTrackMaskImage.size};
    }
}

- (void)standardMask
{
    [CATransaction setAnimationDuration:0.0f];
    _trackMaskLayer.contents = (id)[_trackMaskImage CGImage];
    _trackMaskLayer.frame = self.bounds;
}

#pragma mark - Image Processing

- (UIImage *)cropImage:(UIImage *)image rect:(CGRect)rect
{
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, CGRectApplyAffineTransform(rect, CGAffineTransformMakeScale(image.scale, image.scale)));
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return croppedImage;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // This is only used to turn the image on if you touch down on the switch and
    // don't pan. The updateThumbPositionAnimated: will take care of setting the
    // thumb to a normal state
    [self thumbImageHighlighted:YES];
}

#pragma mark - Auto Layout

- (CGSize)intrinsicContentSize
{
    return self.bounds.size;
}

@end
