/*
 
   Copyright (c) 2006-2013, United States Government as represented by the
   Administrator of the National Aeronautics and Space Administration. All
   rights reserved.
   
   Copyright (c) 2014 Marius Popescu
 
 
   The following code is a derivative work of 'inteprolation-bicubic.glsl', part of the NASA Vision Workbench library
 
   'bicubic-interpolator.vsh' is part of the TJ app.
 
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



#define LEN_X   16.0
#define LEN_Y   16.0

attribute vec4 position;
attribute vec2 textureCoordinate;
//varying   vec2 coordinate;


varying vec2 a99;
varying vec2 a09;
varying vec2 a19;
varying vec2 a29;

varying vec2 a90;
varying vec2 a00;
varying vec2 a10;
varying vec2 a20;

varying vec2 a91;
varying vec2 a01;
varying vec2 a11;
varying vec2 a21;

varying vec2 a92;
varying vec2 a02;
varying vec2 a12;
varying vec2 a22;


void main()
{
	gl_Position = position;
	//coordinate = textureCoordinate; /// vec2(LEN_X, LEN_Y);
 
    a99 = (textureCoordinate + vec2(-1.0, -1.0)) / vec2(LEN_X, LEN_Y);
    a09 = (textureCoordinate + vec2(0.0, -1.0)) / vec2(LEN_X, LEN_Y);
    a19 = (textureCoordinate + vec2(1.0, -1.0)) / vec2(LEN_X, LEN_Y);
    a29 = (textureCoordinate + vec2(2.0, -1.0)) / vec2(LEN_X, LEN_Y);
    
    a90 = (textureCoordinate + vec2(-1.0, 0.0)) / vec2(LEN_X, LEN_Y);
    a00 = (textureCoordinate + vec2(0.0, 0.0)) / vec2(LEN_X, LEN_Y);
    a10 = (textureCoordinate + vec2(1.0, 0.0)) / vec2(LEN_X, LEN_Y);
    a20 = (textureCoordinate + vec2(2.0, 0.0)) / vec2(LEN_X, LEN_Y);
    
    a91 = (textureCoordinate + vec2(-1.0, 1.0)) / vec2(LEN_X, LEN_Y);
    a01 = (textureCoordinate + vec2(0.0, 1.0)) / vec2(LEN_X, LEN_Y);
    a11 = (textureCoordinate + vec2(1.0, 1.0)) / vec2(LEN_X, LEN_Y);
    a21 = (textureCoordinate + vec2(2.0, 1.0)) / vec2(LEN_X, LEN_Y);
    
    a92 = (textureCoordinate + vec2(-1.0, 2.0)) / vec2(LEN_X, LEN_Y);
    a02 = (textureCoordinate + vec2(0.0, 2.0)) / vec2(LEN_X, LEN_Y);
    a12 = (textureCoordinate + vec2(1.0, 2.0)) / vec2(LEN_X, LEN_Y);
    a22 = (textureCoordinate + vec2(2.0, 2.0)) / vec2(LEN_X, LEN_Y);
}

