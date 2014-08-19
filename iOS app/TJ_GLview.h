/*
 
   TJ_GLview.h
 
   Copyright (c) 2014 Marius Popescu
 
 
   'TJ_GLview.h' is part of the TJ app.
 
   TJ app. is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
 
   TJ app. is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
 
   You should have received a copy of the GNU General Public License
   along with TJ app.  If not, see <http://www.gnu.org/licenses/>.
 
 */


#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

#import "TJ_AudioComm.h"

#import <CoreVideo/CVOpenGLESTextureCache.h>


@interface TJ_GLview : GLKViewController

@property (nonatomic, readwrite, retain) NSMutableArray * IRarray;
+ (TJ_GLview*) sharedInstance;

@property (nonatomic, readwrite) BOOL ir_new_frame;
+ (TJ_GLview*) sharedInstance;

- (IBAction)RotateButton:(id)sender;
- (IBAction)FlipButton:(id)sender;

- (IBAction)autoButton:(UIButton *)sender;
- (IBAction)colorButton:(UIButton *)sender;

- (IBAction)rangeMinus:(UIButton *)sender;
- (IBAction)rangePlus:(UIButton *)sender;

- (IBAction)midPlusButton:(UIButton *)sender;
- (IBAction)midMinusButton:(UIButton *)sender;


@property (weak, nonatomic) IBOutlet UIButton *autoButtonProperty;

@property (weak, nonatomic) IBOutlet UILabel *RmaxLabel;
@property (weak, nonatomic) IBOutlet UILabel *TmaxLabel;

@property (weak, nonatomic) IBOutlet UILabel *TminLabel;
@property (weak, nonatomic) IBOutlet UILabel *RminLabel;

@property (weak, nonatomic) IBOutlet UILabel *NETDLabel;


@property (weak, nonatomic) IBOutlet UILabel *T_FFavg;
@property (weak, nonatomic) IBOutlet UILabel *T_FFmax;

@property (weak, nonatomic) IBOutlet UILabel *T_PPmaxLabel;
@property (weak, nonatomic) IBOutlet UILabel *T_PPavgLabel;

@property (weak, nonatomic) IBOutlet UILabel *T_C1Label;
@property (weak, nonatomic) IBOutlet UILabel *T_C2Label;
@property (weak, nonatomic) IBOutlet UILabel *T_C3Label;
@property (weak, nonatomic) IBOutlet UILabel *T_C4Label;
@property (weak, nonatomic) IBOutlet UILabel *T_CavgLabel;

@property (weak, nonatomic) IBOutlet UILabel *TaLabel;
@property (weak, nonatomic) IBOutlet UILabel *T_aDeltaLabel;


@property (strong, nonatomic) EAGLContext *context;

@end
