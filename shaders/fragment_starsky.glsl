#version 430

in vec4 vertexPos;
out vec4 fragColor;

uniform vec2 resolution;
uniform float time;

// I'm using simple random functions to generate 
// a simple yet beautiful starry sky
// 

float FLOAT_MAX = 10e+10;

float RandFloat1(vec2 co)
{
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
float RandFloat2(vec2 co)
{
    return abs(sin(dot(co.xy ,vec2(12.9898,78.233))));
}

vec3 StarField(vec2 coord, in float cellSize, in float starProb, in vec2 starVel, float offset)
{
    //gl_FragCoord.xy += time;
    vec3 col = vec3(0);
    
    if (cellSize > 1.0)
    {
        vec2 cell = coord - mod(coord, cellSize);
        float rnd = RandFloat1(cell + offset);
        if (rnd > 1.0-starProb){
            vec2 center = cell + cellSize/2.0;
            vec2 factor1 = (2.0 / abs(coord - center));
            vec2 factor2 = cos(3.14*(coord - center)/(cellSize/1.0));
            float factor = pow(factor1.x*factor1.y, 1.5) * pow(factor2.y * factor2.x, 2.0+5.0*RandFloat2(cell));
            col = vec3(1,1,1) * factor;
        }
    }
    else
    {
        // Normalized pixel coordinates (from 0 to 1)
        vec2 uv = (coord + offset - 0.5*resolution.xy)/resolution.y;
        float rnd = RandFloat1(uv);
        if (rnd > 1.0-starProb){
            col = vec3(1,1,1);
        }
    }
    
    return col;
}


// Main Function
void main()
{
    // Parameters
    float bgSpeed = 0.1;
    float bgStrength = 0.1;
    vec2 starVel = vec2(1,2);
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (gl_FragCoord.xy - 0.5*resolution.xy)/resolution.xy;
    
    // Background color
    vec3 col = vec3(0);
    col.x = 0.5+0.5*sin(-1.57+uv.x*2.0*1.57 + time*bgSpeed);
    col.y = 0.5+0.5*sin(uv.y*uv.x*1.57 + time*bgSpeed);
    col.z = 0.5+0.5*cos(-1.57+uv.y*2.0*1.57 + time*bgSpeed);
    col *= bgStrength;
    
    // Create multi leveled star field
    col += StarField(gl_FragCoord.xy, 11.0, 0.003, starVel, 3.6);
    col += StarField(gl_FragCoord.xy, 7.0, 0.0035, starVel, 1.3);
    col += StarField(gl_FragCoord.xy, 3.0, 0.001, starVel, 1.3);
    col += StarField(gl_FragCoord.xy, 1.0, 0.0009, starVel, ceil(time/0.1));
    
    // Output to screen
    fragColor = vec4(col,1.0);
}