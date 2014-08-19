/*

   Copyright (c) 2006-2013, United States Government as represented by the
   Administrator of the National Aeronautics and Space Administration. All
   rights reserved.
 
   Copyright (c) 2014 Marius Popescu
 
 
   The following code is a derivative work of 'inteprolation-bicubic.glsl', part of the NASA Vision Workbench library

   'bicubic-interpolator.fsh' is part of the TJ app.
 
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

precision mediump float;
//varying mediump vec2 coordinate;

uniform sampler2D sampler;

varying mediump vec2 a99;
varying mediump vec2 a09;
varying mediump vec2 a19;
varying mediump vec2 a29;

varying mediump vec2 a90;
varying mediump vec2 a00;
varying mediump vec2 a10;
varying mediump vec2 a20;

varying mediump vec2 a91;
varying mediump vec2 a01;
varying mediump vec2 a11;
varying mediump vec2 a21;

varying mediump vec2 a92;
varying mediump vec2 a02;
varying mediump vec2 a12;
varying mediump vec2 a22;

void main()
{
    
   vec2 ij = a00 * vec2(LEN_X, LEN_Y);
   vec2 xy = floor(ij);
   vec2 normxy = ij - xy;
   vec2 st0 = ((2.0 - normxy) * normxy - 1.0) * normxy;
   vec2 st1 = (3.0 * normxy - 5.0) * normxy * normxy + 2.0;
   vec2 st2 = ((4.0 - 3.0 * normxy) * normxy + 1.0) * normxy;
   vec2 st3 = (normxy - 1.0) * normxy * normxy;


    vec4 row0 = st0.s * texture2D(sampler, a99) + st1.s * texture2D(sampler, a09) + st2.s * texture2D(sampler, a19) + st3.s * texture2D(sampler, a29);

    vec4 row1 = st0.s * texture2D(sampler, a90) + st1.s * texture2D(sampler, a00) + st2.s * texture2D(sampler, a10) + st3.s * texture2D(sampler, a20);

    vec4 row2 = st0.s * texture2D(sampler, a91) + st1.s * texture2D(sampler, a01) + st2.s * texture2D(sampler, a11) + st3.s * texture2D(sampler, a21);
    
    vec4 row3 = st0.s * texture2D(sampler, a92) + st1.s * texture2D(sampler, a02) + st2.s * texture2D(sampler, a12) + st3.s * texture2D(sampler, a22);

    gl_FragColor = 0.25 * ((st0.t * row0) + (st1.t * row1) + (st2.t * row2) + (st3.t * row3));
     
    //gl_FragColor = texture2D(sampler, a00);
}


