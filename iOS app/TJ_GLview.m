/*
   TJ_GLview.m
 
   A proof-of-concept testing app. for the TJ Gen1 Prototype
     - still a lot of dirty written code
     - clunky testing-oriented UI
 
 
   Copyright (c) 2014 Marius Popescu
   Copyright (c) 2012 Andy Rawson (mapTempToColor, mapTempToGrayscale, map functions)
 
   Early versions of this file (ca. 2013) were forked from Andy Rawson's open-source IR-BLUE app.
   Kudos to him and his app. for helping me take my first steps with this!
 
   However at this point except for two of the 'palettizing' functions (mapTempToColor, mapTempToGrayscale)
   and the 'palettizing' helper function (map) - marked accordingly in code - no other parts of code from the IR-BLUE project are contained in the TJ app.
   Any minor reminiscents of this legacy, such as variable names are purely unintentional and will be removed in a subsequent TJ app. version
 
 
   'TJ_GLview.m' is part of the TJ app.
 
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

#import "ironbow_palette.h"
#import "TJ_GLview.h"
#import "ShaderUtilities.h"
#import "TJAppDelegate.h"



@interface TJ_GLview ()



#define FPA_AMG 1
#define FPA_D6T 2
#define FPA_MLX 3

#define LEN_X   16
#define LEN_Y   16



{
    TJ_AudioComm* audiocomm;
    
    int ScanFramesCount;

    
    int autoRanging;
    
    int fpa_type, fpa_x, fpa_y;
    int rotate;
    BOOL flip;
    
    double TA, TA_ex;
    
    double TdeltaMax;
    
    double MaxAux;
    double MinAux;
    
    double MaxTemp;
    double MinTemp;
    
    double Maxi[256];
    double Mini[256];
    
    double RangeMaxTemp;
    double RangeMinTemp;
    
    int colorType;

    
    double ir_frame[256], ir_frame_ex[256];
    
    UIColor *colorArrayTemp[16][16];
    
    CGRect screenRect;
    CGFloat screenWidth;
    CGFloat screenHeight;
    
    
    NSData *msg_bound_flag;
    
    CVPixelBufferRef irpixels_buffer;
	CVOpenGLESTextureCacheRef irpixels_buffer_TextureCache;
    CVOpenGLESTextureRef texture;
    
    GLuint bicubic_interpolator;
    
    CGFloat _screenWidth;
    CGFloat _screenHeight;
    
}

@end



enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

static const GLfloat squareVertices_ipad[] = {
    -0.75f, -1.0f,
    0.75f, -1.0f,
    -0.75f, 1.0f,
    0.75f, 1.0f
};

static const GLfloat squareVertices_iphone[] = {
    -0.66f, -1.0f,
    0.66f, -1.0f,
    -0.66f, 1.0f,
    0.66f, 1.0f
};

static const GLfloat squareVertices_wiphone[] = {
    -0.56f, -1.0f,
    0.56f, -1.0f,
    -0.56f, 1.0f,
    0.56f, 1.0f
};


static const GLfloat textureVertices_d6t[] = {
    0.0, 0.0,
    15.0, 0.0,
    0.0, 15.0,
    15.0, 15.0
};


@implementation TJ_GLview

@synthesize context = _context;

@synthesize IRarray;
@synthesize ir_new_frame;

+ (TJ_GLview*) sharedInstance {
    static TJ_GLview *myInstance = nil;
    if (myInstance == nil) {
        myInstance = [[[self class] alloc] init];
        
        myInstance.IRarray = [[NSMutableArray alloc] init];
        myInstance.ir_new_frame = FALSE;
        
        for (int i=0; i<256; i++)
            [myInstance.IRarray addObject:[NSNumber numberWithFloat:0.0]];
    }
    return myInstance;
}


- (const GLchar *)readFile:(NSString *)name
{
    NSString *path;
    const GLchar *source;
    
    path = [[NSBundle mainBundle] pathForResource:name ofType: nil];
    source = (GLchar *)[[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] UTF8String];
    
    return source;
}

- (void)viewDidLoad
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [super viewDidLoad];
    
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    self.preferredFramesPerSecond = 60;
    
    view.contentScaleFactor = 1.0;
    
    [EAGLContext setCurrentContext:_context];
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &irpixels_buffer_TextureCache);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
    }
    
    glDisable(GL_DEPTH_TEST);
    
    
    // Load vertex and fragment shaders
    const GLchar *vertSrc = [self readFile:@"bicubic-interpolator.vsh"];
    const GLchar *fragSrc = [self readFile:@"bicubic-interpolator.fsh"];
    
    // attributes
    GLint attribLocation[NUM_ATTRIBUTES] = {
        ATTRIB_VERTEX, ATTRIB_TEXTUREPOSITON,
    };
    GLchar *attribName[NUM_ATTRIBUTES] = {
        "position", "textureCoordinate",
    };
    
    glueCreateProgram(vertSrc, fragSrc,
                      NUM_ATTRIBUTES, (const GLchar **)&attribName[0], attribLocation,
                      0, 0, 0, // we don't need to get uniform locations in this example
                      &bicubic_interpolator);
    
    [self displayPixelBuffer];
    
    [self initializeThings];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    [self updateColors];
    
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    
    CVPixelBufferLockBaseAddress(irpixels_buffer, 0 );
    int bufferWidth = CVPixelBufferGetWidth(irpixels_buffer);
    uint *pixel = (uint *)CVPixelBufferGetBaseAddress(irpixels_buffer);
    uint aux;
    int x_offset;
    
    for(int y = 0; y < fpa_y; y++)
    {
        for(int x = 0; x < fpa_x; x++)
        {
            [colorArrayTemp[x][y] getRed:&red green:&green blue:&blue alpha:&alpha];
            aux = (uint) (0xFF000000 + ((unsigned char) (blue * 255) << 16 ) + ((unsigned char) (green * 255) << 8) + (unsigned char) (red * 255));
            
            x_offset = y * bufferWidth + x;
            pixel[x_offset] = aux;
        }
    }
    
    CVPixelBufferUnlockBaseAddress( irpixels_buffer, 0 );
    
    // Update attribute values.
    
	glEnableVertexAttribArray(ATTRIB_VERTEX);
    

    if (fpa_type == 2)
    {
        if (screenHeight == 480)
            glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices_iphone);
        else if (screenHeight == 568)
            glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices_wiphone);
        else if (screenHeight == 1024)
            glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices_ipad);
        
        glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureVertices_d6t);
    }
    
    

	glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) displayPixelBuffer
{
    
    
    NSMutableDictionary*     attributes;
    attributes = [NSMutableDictionary dictionary];
    
    NSDictionary *IOSurfaceProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESFBOCompatibility",[NSNumber numberWithBool:YES], @"IOSurfaceOpenGLESTextureCompatibility",nil];
    
    [attributes setObject:IOSurfaceProperties forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
    
    
    CVPixelBufferCreate(kCFAllocatorDefault, LEN_X, LEN_Y, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attributes, &irpixels_buffer);
    
    
    
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                irpixels_buffer_TextureCache,
                                                                irpixels_buffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RGBA,
                                                                LEN_X,
                                                                LEN_Y,
                                                                GL_RGBA,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &texture);
    
    
    
    if (!texture || err) {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
        return;
    }
    
	glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    
    // Set texture parameters
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    // Use shader program.
    glUseProgram(bicubic_interpolator);
}

- (void)initializeThings
{
	

    audiocomm = [[TJ_AudioComm alloc] init];
    [audiocomm startIOUnit];

    fpa_type = 2;
    fpa_x = 16;
    fpa_y = 16;

    flip = FALSE;

    autoRanging = 1;

    RangeMinTemp = 20;
    RangeMaxTemp = 21;
    
    colorType = 0;
    rotate = 0;
    
    screenRect = [[UIScreen mainScreen] bounds];
    screenWidth = screenRect.size.width;
    screenHeight = screenRect.size.height;
    
    [self updateRangeLabels];
}


-(void)appWillResignActive
{
    glFinish();
}

-(void)appDidBecomeActive
{
}

-(void)appWillTerminate:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
}


-(void)updateColors {
    
    static int frames_without_update = 0;
    
    if ([TJ_GLview sharedInstance].ir_new_frame == FALSE)
    {
        frames_without_update++;
       return;
    }
    else
    {
        printf("\n Frames without update: %i", frames_without_update);
        frames_without_update = 0;
    }
    
    for (int i=0; i<256; i++)
    {
        ir_frame_ex[i] = ir_frame[i];
        ir_frame[i] = [(NSNumber*)[[TJ_GLview sharedInstance].IRarray objectAtIndex:i] floatValue];
    }
    
    [TJ_GLview sharedInstance].ir_new_frame = FALSE;
    
    MinTemp = ir_frame[0];
    MaxTemp = ir_frame[0];
    
    TdeltaMax = 0;
    
    for (int i = 0; i < (fpa_x * fpa_y); i++)
    {
        Mini[i] = ir_frame[i];
        Maxi[i] = ir_frame[i];
    }
    
    double temp_aux[16][16];
    int i = 0;
    
    for (int x = 0; x < fpa_x; x++)
        for (int y = fpa_y - 1; y >= 0; y--)
        {
            temp_aux[x][y] = ir_frame[i];
            
            double temp = temp_aux[x][y];
            
            if (temp > MaxTemp)
                MaxTemp = temp;
            else if (temp < MinTemp)
                MinTemp = temp;
            
            if (temp > Maxi[i])
                Maxi[i] = temp;
            else if (temp < Mini[i])
                Mini[i] = temp;
            
            if (i == 6)
            {
                if (temp > MaxAux){
                    MaxAux = temp;
                }
                else if (temp < MinAux) {
                    MinAux = temp;
                }
            }
            
            i++;
        }
    
    if (autoRanging)
    {
        RangeMaxTemp = MaxTemp;
        RangeMinTemp = MinTemp;
        
        [self updateRangeLabels];
        
    }
    
    int x_idx, y_idx;
    
    for (int y = 0; y < fpa_y; y++)
        for (int x = 0; x < fpa_x; x++)
        {
            double temp = temp_aux[x][y];
            
            
            if (rotate == 0)
            {
                if (flip)
                    x_idx = fpa_x - x - 1;
                else
                    x_idx = x;
                
                
                y_idx = y;
            }
            else if (rotate == 1)
            {
                if (flip)
                    x_idx = y;
                else
                    x_idx = fpa_y - y - 1;
                
                y_idx = x;
            }
            else if (rotate == 2)
            {
                if (flip)
                    x_idx = x;
                else
                    x_idx = fpa_x - x - 1;
                
                y_idx = fpa_y - y - 1;
            }
            else if (rotate == 3)
            {
                if (flip)
                    x_idx = fpa_y - y - 1;
                else
                    x_idx = y;
                
                y_idx = fpa_x - x - 1;
            }
            
            switch (colorType) {
                case 0:
                    colorArrayTemp[x_idx][y_idx] = [self mapTempToIron:temp];
                    break;
                case 1:
                    colorArrayTemp[x_idx][y_idx] = [self mapTempToColor:temp];
                    break;
                case 2:
                    colorArrayTemp[x_idx][y_idx] = [self mapTempToGreyscale:temp];
                    break;
                    
                default:
                    break;
            }
        }
    
    
    [self updateTempLabels];
}

- (UIColor *)mapTempToIron:(float)tempValue {
    
    int color_index = ((int) ((tempValue - RangeMinTemp) / (RangeMaxTemp - RangeMinTemp) * 119)) * 3;
    
    if (color_index > 357)
        color_index = 357;
    if (color_index < 0)
        color_index = 0;
    
    float r = ironbow_palette[color_index] / 255.0;
    float g = ironbow_palette[color_index + 1] / 255.0;
    float b = ironbow_palette[color_index + 2] / 255.0;
    
    return [UIColor colorWithRed:r green:g blue:b alpha:1];
}


// this function is part of the IR-BLUE project
-(float) map :(float) inMin :(float) inMax :(float) outMin :(float) outMax :(float) inValue {
    float result = 0;
    result = outMin + (outMax - outMin) * (inValue - inMin) / (inMax - inMin);
    return result;
}

// this function is part of the IR-BLUE project
- (UIColor *)mapTempToColor:(float)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat hue;
    
    hue = [self map:RangeMinTemp :RangeMaxTemp :0.75 :0.0 :tempValue];  //  0.0 to 1.0
    
    if (hue >0.75) hue = 0.75;
    else if (hue < 0.0) hue = 0.0;
    CGFloat saturation = 1;
    CGFloat brightness = 1;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

// this function is part of the IR-BLUE project
- (UIColor *)mapTempToGreyscale:(float)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat brightness;
    
    brightness = [self map:RangeMinTemp :RangeMaxTemp :0.0 :1.0 :tempValue];  //  0.0 to 1.0
    
    if (brightness >1) brightness = 1;
    else if (brightness < 0.0) brightness = 0.0;
    CGFloat hue = 0.17;
    CGFloat saturation = 0.1;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"Got a Memory Warning");
    //Dispose of any resources that can be recreated.
}


-(void) updateTempLabels {
    float Tptop, TptopAvg = 0, TptopMax = 0, TptopMin;
    float Tftof, TftofAvg = 0, TftofMax = 0, TftofMin, NETD;
    int count;
    
    self.TaLabel.text = [NSString stringWithFormat:@"T A %.2lf", TA];
    self.T_aDeltaLabel.text = [NSString stringWithFormat:@"T AΔ %.2lf", fabs(TA - TA_ex)];
    
    self.TmaxLabel.text = [NSString stringWithFormat:@"T max %.2lf", MaxTemp];
    self.TminLabel.text = [NSString stringWithFormat:@"T min %.2lf", MinTemp];
    
    count = 0;
    
    TftofMin = MaxTemp;
    NETD = MaxTemp;
    
    for (int i = 0; i < (fpa_x * fpa_y); i++)
    {
        count++;
        
        Tftof = fabs(ir_frame[i] - ir_frame_ex[i]);
        
        TftofAvg += Tftof;
        
        if (Tftof > TftofMax)
            TftofMax = Tftof;
        if (Tftof < TftofMin)
            TftofMin = Tftof;
        if ((Tftof < NETD) && (Tftof > 0.005))
            NETD = Tftof;
    }
    
    if (NETD > TftofMax)
        NETD = TftofMax;
    
    if (fabs(TA - TA_ex) == 0)
        self.NETDLabel.text = [NSString stringWithFormat:@"T Res %.2lf", NETD];
    
    TftofAvg /= count;
    
    self.T_FFavg.text = [NSString stringWithFormat:@"T FFΔavg %.2lf", TftofAvg];
    self.T_FFmax.text = [NSString stringWithFormat:@"T FFΔmax %.2lf", TftofMax];
    
    count = 0;
    TptopMin = MaxTemp;
    
    for(int i = 0; i < (fpa_x * fpa_y - 1); i++)
    {
        for (int j = i+1; j < (fpa_x * fpa_y); j++)
        {
            count++;
            
            Tptop = fabs(ir_frame[j] - ir_frame[i]);
            TptopAvg += Tptop;
            
            if (Tptop > TptopMax)
                TptopMax = Tptop;
            if (Tptop < TptopMin)
                TptopMin = Tptop;
        }
    }
    if (TptopMin > TptopMax)
        TptopMin = TptopMax;
    
    TptopAvg /= count;
    
    self.T_PPavgLabel.text = [NSString stringWithFormat:@"T PPΔavg %.2lf", TptopAvg];
    self.T_PPmaxLabel.text = [NSString stringWithFormat:@"T PPΔmax %.2lf", TptopMax];
    
    if (fpa_type == FPA_D6T)
    {
        self.T_C1Label.text = [NSString stringWithFormat:@"T C1 %.2lf", ir_frame[119]];
        self.T_C2Label.text = [NSString stringWithFormat:@"T C2 %.2lf", ir_frame[120]];
        self.T_C3Label.text = [NSString stringWithFormat:@"T C3 %.2lf", ir_frame[135]];
        self.T_C4Label.text = [NSString stringWithFormat:@"T C4 %.2lf", ir_frame[136]];
        self.T_CavgLabel.text = [NSString stringWithFormat:@"T Cavg %.2lf", (ir_frame[119] + ir_frame[120] + ir_frame[121] + ir_frame[122]) / 4];
    }
}

-(void) updateRangeLabels {
    self.RmaxLabel.text = [NSString stringWithFormat:@"R max %.1lf", RangeMaxTemp];
    self.RminLabel.text = [NSString stringWithFormat:@"R min %.1lf", RangeMinTemp];
}


- (IBAction)RotateButton:(id)sender {
    rotate = (++rotate) % 4;
}

- (IBAction)FlipButton:(id)sender {
    flip ^= 1;
}

- (IBAction)autoButton:(UIButton *)sender {

        
        if (autoRanging) {
            autoRanging = 0;
            
            RangeMaxTemp = round(MaxTemp);
            RangeMinTemp = round(MinTemp);
            
            [[self autoButtonProperty] setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            
        }
        else {
            
            autoRanging = 1;
            
            RangeMaxTemp = MaxTemp;
            RangeMinTemp = MinTemp;
            
            [self updateRangeLabels];
            
            [[self autoButtonProperty] setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        }
}

- (IBAction)rangeMinus:(UIButton *)sender {
    if (!autoRanging) {
        
        if (RangeMinTemp < RangeMaxTemp)
        {
            RangeMinTemp = RangeMinTemp + 0.5;
            RangeMaxTemp = RangeMaxTemp - 0.5;
        }
        
        [self updateRangeLabels];
    }
}

- (IBAction)rangePlus:(UIButton *)sender {
    if (!autoRanging) {
        RangeMinTemp = RangeMinTemp - 0.5;
        RangeMaxTemp = RangeMaxTemp + 0.5;
        
        [self updateRangeLabels];
    }
}

- (IBAction)midPlusButton:(UIButton *)sender {
    if (!autoRanging) {
        RangeMinTemp = RangeMinTemp + 0.5;
        RangeMaxTemp = RangeMaxTemp + 0.5;
        
        [self updateRangeLabels];
    }
}

- (IBAction)midMinusButton:(UIButton *)sender {
    if (!autoRanging) {
        RangeMinTemp = RangeMinTemp - 0.5;
        RangeMaxTemp = RangeMaxTemp - 0.5;
        
        [self updateRangeLabels];
    }
}

- (IBAction)colorButton:(UIButton *)sender {
    
        if (colorType == 2) {
            colorType = 0;
        }
        else {
            colorType++;
        }
}


@end
