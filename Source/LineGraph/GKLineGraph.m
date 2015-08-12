//
//  GKLineGraph.m
//  GraphKit
//
//  Copyright (c) 2014 Michal Konturek
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "GKLineGraph.h"

#import "ViewFrameAccessor.h"
#import "NSArray+MK.h"
#import "GKCircle.h"

static CGFloat kDefaultLabelWidth = 40.0;
static CGFloat kDefaultLabelHeight = 12.0;
static NSInteger kDefaultValueLabelCount = 5;
static CGFloat kDefaulDotRadius = 10.0;
static NSInteger kDefaultPerPageCount = 7;

static CGFloat kDefaultLineWidth = 3.0;
static CGFloat kDefaultMargin = 10.0;
static CGFloat kDefaultMarginBottom = 20.0;

static CGFloat kAxisMargin = 20.0;

@interface GKLineGraph ()

@property (nonatomic, strong) NSArray *titleLabels;
@property (nonatomic, strong) NSArray *valueLabels;


@end

@implementation GKLineGraph

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _init];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _init];
    }
    return self;
}

- (void)initScrollView
{
    //init scrollview
    if ([self.scrollView superview] != self) {
        CGRect scrollFrame = self.bounds;
        scrollFrame.size.width =   self.frame.size.width-kDefaultLabelWidth;
        scrollFrame.origin.x = kDefaultLabelWidth;
        self.scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
        self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width+80, self.scrollView.frame.size.height);
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        self.scrollView.bounces = NO;
        self.scrollView.delegate = self;
        self.scrollView.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.scrollView];
    }
    else
    {
        if (self.scrollView.subviews.count > 0)
        {
            for (UIView *v in self.scrollView.subviews)
            {
                [v removeFromSuperview];
            }
        }
    }
}

- (void)_init {
    self.animated = YES;
    self.animationDuration = 1;
    self.lineWidth = kDefaultLineWidth;
    self.margin = kDefaultMargin;
    self.valueLabelCount = kDefaultValueLabelCount;
    self.maxValue = 0;
    self.perPageCount = kDefaultPerPageCount;
    self.clipsToBounds = YES;
    
    self.dotRadius = kDefaulDotRadius;
    
    self.alwaysShowLastData = NO;
    self.showZeroData       = YES;
}

- (void)draw {
    
    [self initScrollView];
    
    NSInteger count = [[self.dataSource titleLabelValue] count];
    CGFloat stepX = [self _stepX];
    CGFloat contentSizeWidth = count*stepX+kAxisMargin;
    [self .scrollView setContentSize:CGSizeMake(contentSizeWidth, self.scrollView.frame.size.height)];
    
    
    NSAssert(self.dataSource, @"GKLineGraph : No data source is assgined.");
    
    if ([self _hasTitleLabels]) [self _removeTitleLabels];
    [self _constructTitleLabels];
    [self _positionTitleLabels];

    if ([self _hasValueLabels]) [self _removeValueLabels];
    [self _constructValueLabels];
    
    [self _drawLines];
    
    if (self.alwaysShowLastData)
    {
        CGPoint offset;
        offset.x = self.scrollView.contentSize.width - stepX*(self.perPageCount+1);
        offset.y = self.scrollView.contentOffset.y;
        if (offset.x > 0) {
            self.scrollView.contentOffset = offset;
        }
    }
}

- (BOOL)_hasTitleLabels {
    return ![self.titleLabels mk_isEmpty];
}

- (BOOL)_hasValueLabels {
    return ![self.valueLabels mk_isEmpty];
}

- (void)_constructTitleLabels {
    
    NSInteger count = [[self.dataSource titleLabelValue] count];
    
    id items = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger idx = 0; idx < count; idx++) {
        
        CGRect frame = CGRectMake(0, 0, kDefaultLabelWidth, kDefaultLabelHeight);
        UILabel *item = [[UILabel alloc] initWithFrame:frame];
        item.textAlignment = NSTextAlignmentCenter;
        item.font = [UIFont boldSystemFontOfSize:12];
        item.textColor = [UIColor whiteColor];
        item.backgroundColor = [UIColor clearColor];
        item.text = [self.dataSource titleForLineAtIndex:idx];
        
        
        [items addObject:item];
    }
    self.titleLabels = items;
}

- (void)_removeTitleLabels {
    [self.titleLabels mk_each:^(id item) {
        [item removeFromSuperview];
    }];
    self.titleLabels = nil;
}

- (void)_positionTitleLabels {
    
    __block NSInteger idx = 0;
    id values = [self.dataSource titleLabelValue];
    
    [values mk_each:^(id value) {
        
        CGFloat labelWidth = kDefaultLabelWidth;
        CGFloat labelHeight = kDefaultLabelHeight;
        CGFloat startX = [self _pointXForIndex:idx] - (labelWidth / 2);
        CGFloat startY = (self.height - labelHeight);
        
        UILabel *label = [self.titleLabels objectAtIndex:idx];
        label.x = startX;
        label.y = startY;
        label.backgroundColor = [UIColor clearColor];
        
        [self.scrollView addSubview:label];

        idx++;
    }];
}

- (CGFloat)_pointXForIndex:(NSInteger)index {
    return kAxisMargin+self.margin + (index * [self _stepX]);
}

- (CGFloat)_stepX {
//    id values = [self.dataSource valuesForLineAtIndex:0];
    CGFloat plotWidth = [self _plotWidth];
    CGFloat result = (plotWidth / self.perPageCount);
    return result;
}

- (void)_constructValueLabels {
    
    NSInteger count = self.valueLabelCount;
    id items = [NSMutableArray arrayWithCapacity:count];
    
    for (NSInteger idx = 0; idx < count; idx++) {
        
        CGRect frame = CGRectMake(0, 0, kDefaultLabelWidth, kDefaultLabelHeight);
        UILabel *item = [[UILabel alloc] initWithFrame:frame];
        item.textAlignment = NSTextAlignmentRight;
        item.font = [UIFont boldSystemFontOfSize:12];
        item.textColor = [UIColor whiteColor];
        item.backgroundColor = [UIColor clearColor];
    
        CGFloat value = [self _minValue] + (idx * [self _stepValueLabelY]);
        item.centerY = [self _positionYForLineValue:value];
        
        //在左侧标签旁边画一条横线
        [self _constructValueLabelsLine:item.centerY];
        
        item.text = [@(ceil(value)) stringValue];
//        item.text = [@(value) stringValue];
        
        [items addObject:item];
        [self addSubview:item];
    }
    self.valueLabels = items;
}

- (void)_constructValueLabelsLine :(CGFloat)centerY{
    
    UIGraphicsBeginImageContext(self.frame.size);
    
    UIBezierPath *path = [self _bezierPathWith:0];
    CAShapeLayer *layer = [self _layerWithPath:path];
    layer.strokeColor = [[UIColor colorWithRed:0 green:172.0/255 blue:231.0/255 alpha:1.0] CGColor];//[[UIColor whiteColor] CGColor];
    layer.lineWidth = 0.5;
    
    [self.layer addSublayer:layer];
    
    CGPoint startPoint = CGPointMake(kDefaultLabelWidth+5.0, centerY);
    CGPoint endePoint = CGPointMake(self.frame.size.width-self.margin , centerY);
    
    [path moveToPoint:startPoint];
    [path addLineToPoint:endePoint];
    layer.path = path.CGPath;
    
    UIGraphicsEndImageContext();
    
}

- (CGFloat)_stepValueLabelY {
    return (([self _maxValue] - [self _minValue]) / (self.valueLabelCount - 1));
}

- (CGFloat)_maxValue {
    id values = [self _allValues];
    
    float maxOfValues = [[values mk_max] floatValue];
    if (self.maxValue > 0 && maxOfValues < self.maxValue) {
        return self.maxValue;
    };
    return [[values mk_max] floatValue];
}

- (CGFloat)_minValue {
    if (self.startFromZero) return 0;
    
    id values = [self _allValues];
    float minOfValues = [[values mk_min] floatValue];
    if (self.minValue >= 0 && self.minValue < minOfValues) {
        return self.minValue;
    };
    return minOfValues;
}

- (NSArray *)_allValues {
    NSInteger count = [self.dataSource numberOfLines];
    id values = [NSMutableArray array];
    for (NSInteger idx = 0; idx < count; idx++) {
        id item = [self.dataSource valuesForLineAtIndex:idx];
        [values addObjectsFromArray:item];
    }
    return values;
}

- (void)_removeValueLabels {
    [self.valueLabels mk_each:^(id item) {
        [item removeFromSuperview];
    }];
    self.valueLabels = nil;
}

- (CGFloat)_plotWidth {
    
    return (self.scrollView.width - (2 * self.margin) - kAxisMargin);
}

- (CGFloat)_plotHeight {
    return (self.height - (2 * kDefaultLabelHeight + kDefaultMarginBottom));
}

- (void)_drawLines {
    for (NSInteger idx = 0; idx < [self.dataSource numberOfLines]; idx++) {
        [self _drawLineAtIndex:idx];
    }
}



- (void)_drawLineAtIndex:(NSInteger)index {
    
    // http://stackoverflow.com/questions/19599266/invalid-context-0x0-under-ios-7-0-and-system-degradation
    UIGraphicsBeginImageContext(self.frame.size);
    
    UIBezierPath *path = [self _bezierPathWith:0];
    CAShapeLayer *layer = [self _layerWithPath:path];
    
    layer.strokeColor = [[self.dataSource colorForLineAtIndex:index] CGColor];
    
    [self.scrollView.layer addSublayer:layer];
    
    NSInteger idx = 0;
    NSArray *values = [self.dataSource valuesForLineAtIndex:index];
    for (int i = 0;i < [self.titleLabels count];i++) {
        UILabel *titleLabel = [self.titleLabels objectAtIndex:i];
        NSString *value = nil;
        for (int j = 0; j < [values count]; j++) {
            value = [values objectAtIndex:j];
            NSString *tmpLabel = [[self.dataSource labelsForValue] objectAtIndex:j];
            if (![tmpLabel isEqualToString:titleLabel.text]) {
                value = @"0";
            }
            else
            {
                break;
            }
        }
        
        if (!self.showZeroData && [value integerValue] == 0)
        {
            idx++;
            continue;
        }
        
        CGFloat x = [self _pointXForIndex:idx];
        CGFloat y = [self _positionYForLineValue:[value floatValue]];
        CGPoint point = CGPointMake(x, y);
        
        if (idx != 0) [path addLineToPoint:point];
        
        [path moveToPoint:point];
        
        
        //添加圆点
        GKCircle *circle = [[GKCircle alloc] initWithFrame:CGRectMake(0, 0, self.dotRadius, self.dotRadius)];
        circle.center = CGPointMake(x, y);
        circle.alpha = 0.8;
        //给圆点添加点击事件
        UIButton *circleButton = [[UIButton alloc] initWithFrame:CGRectInset(circle.frame, -10, -10)];
        circleButton.tag = idx;
        if ([value integerValue] == 0) {
            //隐藏圆点
            circle.alpha = 0;
            circleButton.hidden = YES;
        }
        if ([_delegate respondsToSelector:@selector(clickCircle:)]) {
            [circleButton addTarget:_delegate action:@selector(clickCircle:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        //在圆点上方添加显示数值的标签
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kDefaultLabelWidth, kDefaultLabelHeight)];
        valueLabel.center = CGPointMake(x, y+1.2*kDefaultLabelHeight);
        valueLabel.backgroundColor = [UIColor clearColor];
        valueLabel.textColor = [UIColor whiteColor];
        valueLabel.font = [UIFont boldSystemFontOfSize:10.0f];
        valueLabel.textAlignment = NSTextAlignmentCenter;
        NSInteger integerValue = [value integerValue];
        if (integerValue == 0) {
            valueLabel.text = @"";
            
        }else{
            valueLabel.text = [NSString stringWithFormat:@"%d",integerValue];
        }
        [self.scrollView addSubview:valueLabel];
        
        [self.scrollView addSubview:circle];
        [self.scrollView addSubview:circleButton];
        
        idx++;
    }
    
    layer.path = path.CGPath;
    
    if (self.animated) {
        CABasicAnimation *animation = [self _animationWithKeyPath:@"strokeEnd"];
        if ([self.dataSource respondsToSelector:@selector(animationDurationForLineAtIndex:)]) {
            animation.duration = [self.dataSource animationDurationForLineAtIndex:index];
        }
        [layer addAnimation:animation forKey:@"strokeEndAnimation"];
    }
    
    UIGraphicsEndImageContext();
}

- (CGFloat)_positionYForLineValue:(CGFloat)value {
    CGFloat scale = (value - [self _minValue]) / ([self _maxValue] - [self _minValue]);
//    CGFloat scale = (value - _minValue)/(_maxValue - _minValue);
    CGFloat result = [self _plotHeight] * scale;
    result = ([self _plotHeight] -  result);
    result += kDefaultLabelHeight;
    return result;
}

- (UIBezierPath *)_bezierPathWith:(CGFloat)value {
    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineWidth = self.lineWidth;
    return path;
}

- (CAShapeLayer *)_layerWithPath:(UIBezierPath *)path {
    CAShapeLayer *item = [CAShapeLayer layer];
    item.fillColor = [[UIColor blackColor] CGColor];
    item.lineCap = kCALineCapRound;
    item.lineJoin  = kCALineJoinRound;
    item.lineWidth = self.lineWidth;
//    item.strokeColor = [self.foregroundColor CGColor];
    item.strokeColor = [[UIColor redColor] CGColor];
    item.strokeEnd = 1;
    return item;
}

- (CABasicAnimation *)_animationWithKeyPath:(NSString *)keyPath {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = self.animationDuration;
    animation.fromValue = @(0);
    animation.toValue = @(1);
//    animation.delegate = self;
    return animation;
}

- (void)reset {
//    self.scrollView.layer.sublayers = nil;  delete 2015-01-01
    [self _removeTitleLabels];
    [self _removeValueLabels];
}

@end
