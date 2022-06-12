#version 430

in vec3 in_position;

out vec4 vertexOutPos;

void main()
{
    gl_Position = vec4(in_position,1.0);
    vertexOutPos = vec4(vec3(0),1.0);
}