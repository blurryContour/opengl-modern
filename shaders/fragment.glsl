#version 430

in vec4 vertexPos;
out vec4 fragColor;

uniform sampler2D tex1;
uniform sampler2D tex2;

uniform vec2 resolution;
uniform float time;

void main(){

    vec2 uv = gl_FragCoord.xy/resolution.xy;

    vec3 col;
    if (uv.x > 0.5)
        col = texture(tex1, uv).xyz;
    else
        col = texture(tex2, uv).xyz;

    fragColor = vec4(col,1);
}