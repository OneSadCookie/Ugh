#version 150

uniform mat4 mvp;

in vec4 position;

void main()
{
    gl_Position = mvp * position;
}

