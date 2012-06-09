#version 150

uniform mat4 mvp;

in vec4 position;
in vec2 texCoords;

out vec2 tc;

void main()
{
    gl_Position = mvp * position;
    tc = texCoords;
}
