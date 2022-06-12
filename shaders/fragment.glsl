#version 430

in vec4 vertexPos;

out vec4 fragColor;

uniform vec2 resolution;
uniform float time;

void main()
{
    // Normalized pixel coordinates (from 0 to 1)
    // vec2 uv = gl_FragCoord.xy/resolution.xy;
    vec2 uv = gl_FragCoord.xy/resolution.xy;

    // Circle params
    float r = 0.1;
    vec2 c = vec2(0.5 + 0.3*sin(time*2.0), 0.5 + 0.3*cos(1.0+time*3.0));
    
    float ar = resolution.y/resolution.x;
    vec2 xy = uv;
    xy -= c;
    xy.y *= ar;
    float d = length(xy);
    vec3 col = vec3(0,0,0);
    col.x = 0.5+0.5*sin(-1.57+uv.x*2.0*1.57 + time);
    col.y = 0.5+0.5*sin(uv.x*1.57 + time);
    col.z = 0.5+0.5*cos(-1.57+uv.y*2.0*1.57 + time);
    
    if (d <= r){
        float r = uv.x + 0.5*sin(time*2.0);
        float g = uv.y + 0.5*cos(time*2.0);
        float b = 0.5 + 0.5*sin(time*2.0);
        col = vec3(r,g,b);
    }
    
    // Output to screen
    fragColor = vec4(col,1.0);
}