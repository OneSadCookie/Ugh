#version 150

uniform sampler2D tex;

in vec2 tc;

out vec4 color;

void main()
{
    color = texture(tex, tc);
}
