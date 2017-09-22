//
//  DetailViewController.h
//  STCObfuscator
//
//  Created by chenxiancai on 21/09/2017.
//  Copyright © 2017 stevchen. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) NSDate *detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end

