#import <glm.hpp>
#import <ext.hpp>

#import <mach/mach_time.h>
#import <OpenGL/gl3.h>

#import "UGHGLView.h"

#define ROTATION_SPEED M_PI

@implementation UGHGLView
{
    GLuint _vao;
    
    GLuint _vbo;
    GLuint _ebo;
    
    GLuint _program;
    GLuint _mvpLocation;
    
    struct mach_timebase_info _timebase;
    uint64_t _lastFrameTime;
    float _rotation;
}

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:(NSOpenGLPixelFormatAttribute[]) {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0,
    }];

    self = [super initWithFrame:frameRect pixelFormat:format];
    if (!self) return nil;
    
    [NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(timer) userInfo:nil repeats:YES];
    
    return self;
}

- (void)timer
{
    if (_lastFrameTime == 0)
    {
        mach_timebase_info(&_timebase);
        _lastFrameTime = mach_absolute_time();
    }
    
    uint64_t now = mach_absolute_time();
    uint64_t delta = now - _lastFrameTime;
    _lastFrameTime = now;
    
    double dt = (double)delta * 0.000000001 * (double)_timebase.numer / (double)_timebase.denom;
    
    _rotation += ROTATION_SPEED * dt;
    if (_rotation > M_PI) _rotation -= 2.0 * M_PI;
    
    [self setNeedsDisplay:YES];
}

- (void)prepareOpenGL
{
    NSLog(@"prepareOpenGL");
    
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, 4 * 4 * sizeof(float), (float[]) {
        -1.0, -1.0, -1.0, 1.0,
         1.0, -1.0, -1.0, 1.0,
         1.0, -1.0,  1.0, 1.0,
        -1.0, -1.0,  1.0, 1.0, 
    }, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(0);
    
    glGenBuffers(1, &_ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 2 * 3 * sizeof(unsigned short), (unsigned short[]) {
        0, 1, 2,
        0, 2, 3,
    }, GL_STATIC_DRAW);
    
    NSData *vshText = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"basic" withExtension:@"vsh"]];
    if (!vshText) abort();
    if ([vshText length] > INT_MAX) abort();
    GLuint vsh = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vsh, 1, (char const * []) { (char const *)[vshText bytes] }, (GLint []) { (GLint)[vshText length] });
    glCompileShader(vsh);
    GLint vshCompiled;
    glGetShaderiv(vsh, GL_COMPILE_STATUS, &vshCompiled);
    if (!vshCompiled) abort();
    
    NSData *fshText = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"basic" withExtension:@"fsh"]];
    if (!fshText) abort();
    if ([fshText length] > INT_MAX) abort();
    GLuint fsh = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fsh, 1, (char const * []) { (char const *)[fshText bytes] }, (GLint []) { (GLint)[fshText length] });
    glCompileShader(fsh);
    GLint fshCompiled;
    glGetShaderiv(fsh, GL_COMPILE_STATUS, &fshCompiled);
    if (!fshCompiled) abort();
    
    _program = glCreateProgram();
    glAttachShader(_program, vsh);
    glAttachShader(_program, fsh);
    glBindAttribLocation(_program, 0, "position");
    glLinkProgram(_program);
    GLint linked;
    glGetProgramiv(_program, GL_LINK_STATUS, &linked);
    if (!linked) abort();
    glDetachShader(_program, vsh);
    glDeleteShader(vsh);
    glDetachShader(_program, fsh);
    glDeleteShader(fsh);
    
    _mvpLocation = glGetUniformLocation(_program, "mvp");
}

- (void)drawRect:(NSRect)dirtyRect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glm::mat4x4 mv = glm::lookAt(
        glm::vec3(5.0f * cosf(_rotation), 5.0f, 5.0f * sinf(_rotation)),
        glm::vec3(0.0f, 0.0f, 0.0f),
        glm::vec3(0.0f, 1.0f, 0.0f));
    glm::mat4x4 p = glm::perspective(60.0f, 8.0f/5.0f, 0.01f, 100.0f);
    glm::mat4x4 mvp = p * mv;
    
    glUseProgram(_program);
    glUniformMatrix4fv(_mvpLocation, 1, GL_FALSE, glm::value_ptr(mvp));
    
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0);
    
    [[self openGLContext] flushBuffer];
}

@end
