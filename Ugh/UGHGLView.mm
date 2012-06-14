#import <vector>

#import <mach/mach_time.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>

#import <glm/glm.hpp>
#import <glm/ext.hpp>

#import "stb_image.h"

#import "UGHGLView.h"

#define ROTATIONS_PER_SECOND 0.125
#define ROTATION_SPEED (ROTATIONS_PER_SECOND * 2.0 * M_PI)

static char Map[] =
    "xxxxxxxx"
    "x   x  x"
    "x   x  x"
    "xxx x xx"
    "x x    x"
    "x xxx  x"
    "x      x"
    "xxxxxxxx";    

#define MAP_WIDTH 8
#define MAP_HEIGHT 8

@implementation UGHGLView
{
    GLuint _vao;
    
    GLuint _vbo;
    GLuint _ebo;
    
    GLuint _program;
    GLuint _mvpLocation;
    GLuint _texLocation;
    
    GLuint _colorTexture;
    GLuint _depthTexture;
    GLuint _fbo;
    
    GLuint _floorTexture;
    GLuint _wallTexture;
    
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
    assert(format);
    
    NSLog(@"hi");

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

static void set_texture_params(GLenum wrap_s, GLenum wrap_t, GLenum mag, GLenum min)
{
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrap_s);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrap_t);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, mag);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, min);
}

static GLuint load_texture(NSData *imageData)
{
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    if (!imageData) abort();
    if ([imageData length] > INT_MAX) abort();
    int w, h, comp;
    void *pixels = stbi_load_from_memory((const stbi_uc *)[imageData bytes], [imageData length], &w, &h, &comp, 4);
    if (!pixels) abort();
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 4.0f);
    set_texture_params(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE, GL_LINEAR, GL_LINEAR_MIPMAP_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glGenerateMipmap(GL_TEXTURE_2D);
    free(pixels);
    return texture;
}

- (void)prepareOpenGL
{
    NSLog(@"prepareOpenGL");
    
    struct {
        char const *name;
        bool        present;
    } requiredExtensions[] = {
        { "GL_EXT_texture_filter_anisotropic", false },
    };
    
    GLint extensionCount;
    glGetIntegerv(GL_NUM_EXTENSIONS, &extensionCount);
    for (GLint i = 0; i < extensionCount; ++i)
    {
        char const *ext = (char const *)glGetStringi(GL_EXTENSIONS, i);
        for (auto &req : requiredExtensions)
        {
            if (strcmp(req.name, ext) == 0)
            {
                req.present = true;
                break;
            }
        }
    }
    for (auto const &req : requiredExtensions)
    {
        if (!req.present) abort();
    }
    
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    glm::vec3 axes[] = { glm::vec3(1, 0, 0), glm::vec3(-1, 0, 0), glm::vec3(0, 1, 0), glm::vec3(0, -1, 0), glm::vec3(0, 0, 1), glm::vec3(0, 0, -1) };
    glm::vec2 offsets[] = { glm::vec2(-1, -1), glm::vec2(1, -1), glm::vec2(1, 1), glm::vec2(-1, 1) };
    std::vector<float> vboData;
    for (auto const &axis: axes)
    {
        glm::vec3 perp0, perp1;
        perp0 = glm::vec3(0, 1, 1) - glm::abs(axis);
        perp1 = glm::vec3(1, 0, 1) - glm::abs(axis);
        if (glm::length(perp0) > 1.0001f) perp0 = glm::vec3(1, 1, 0) - glm::abs(axis);
        else if (glm::length(perp1) > 1.0001f) perp1 = glm::vec3(1, 1, 0) - glm::abs(axis);
        
        for (auto const &offset: offsets)
        {
            glm::vec3 vertex = axis + offset.x * perp0 + offset.y * perp1;
            glm::vec2 tc = 0.5f * offset + 0.5f;
            
            // waiting on a newer compiler...
            // vboData.insert(vboData.end(), { vertex.x, vertex.y, vertex.z, 1.0, tc.x, tc.y });
            vboData.push_back(vertex.x);
            vboData.push_back(vertex.y);
            vboData.push_back(vertex.z);
            vboData.push_back(1.0f);
            vboData.push_back(tc.x);
            vboData.push_back(tc.y);
        }
    }
    
    glGenBuffers(1, &_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, vboData.size() * sizeof(float), &(vboData[0]), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void const *)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void const *)(4 * sizeof(float)));
    glEnableVertexAttribArray(1);
    
    std::vector<unsigned short> eboData;
    for (unsigned i = 0; i < 6; ++i)
    {
        unsigned base = i * 4;
    
        // waiting on a newer compiler...
        // eboData.insert(eboData.end(), { base + 0, base + 1, base + 2, base + 0, base + 2, base + 3 });
        eboData.push_back(base + 0);
        eboData.push_back(base + 1);
        eboData.push_back(base + 2);
        eboData.push_back(base + 0);
        eboData.push_back(base + 2);
        eboData.push_back(base + 3);
    }
    
    glGenBuffers(1, &_ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, eboData.size() * sizeof(unsigned short), &(eboData[0]), GL_STATIC_DRAW);
    
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
    glBindAttribLocation(_program, 1, "texCoords");
    glLinkProgram(_program);
    GLint linked;
    glGetProgramiv(_program, GL_LINK_STATUS, &linked);
    if (!linked) abort();
    glDetachShader(_program, vsh);
    glDeleteShader(vsh);
    glDetachShader(_program, fsh);
    glDeleteShader(fsh);
    
    _mvpLocation = glGetUniformLocation(_program, "mvp");
    _texLocation = glGetUniformLocation(_program, "tex");
    
    glGenTextures(1, &_colorTexture);
    glBindTexture(GL_TEXTURE_2D, _colorTexture);
    set_texture_params(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE, GL_LINEAR, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 800, 500, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glGenTextures(1, &_depthTexture);
    glBindTexture(GL_TEXTURE_2D, _depthTexture);
    set_texture_params(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE, GL_LINEAR, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, 800, 500, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
    
    glGenFramebuffers(1, &_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, _colorTexture, 0);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, _depthTexture, 0);
    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
    
    _wallTexture = load_texture([NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"bright_squares" withExtension:@"png"]]);
    _floorTexture = load_texture([NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"noise_pattern_with_crosslines" withExtension:@"png"]]);
    
    glDepthFunc(GL_LEQUAL);
    glEnable(GL_DEPTH_TEST);
    //glEnable(GL_CULL_FACE);
}

- (void)drawRect:(NSRect)dirtyRect
{
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _fbo);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glm::mat4x4 v = glm::lookAt(
        glm::vec3(MAP_WIDTH + 10.0f * cosf(_rotation), 10.0f, MAP_HEIGHT + 10.0f * sinf(_rotation)),
        glm::vec3(MAP_WIDTH, 0.0f, MAP_HEIGHT),
        glm::vec3(0.0f, 1.0f, 0.0f));
    glm::mat4x4 p = glm::perspective(60.0f, 8.0f/5.0f, 0.01f, 100.0f);
    glm::mat4x4 vp = p * v;
    
    glUseProgram(_program);
    glUniform1i(_texLocation, 0);

    for (unsigned y = 0; y < MAP_HEIGHT; ++y)
    {
        for (unsigned x = 0; x < MAP_WIDTH; ++x)
        {
            if (Map[x + y * MAP_WIDTH] == 'x')
            {
                glm::mat4x4 m = glm::translate(2.0f * float(x), 0.0f, 2.0f * float(y));
                glm::mat4x4 mvp = vp * m;
            
                glUniformMatrix4fv(_mvpLocation, 1, GL_FALSE, glm::value_ptr(mvp));
                glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0);

            }
        }
    }
    
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    glBlitFramebuffer(0, 0, 800, 500, 0, 0, 800, 500, GL_COLOR_BUFFER_BIT, GL_LINEAR);
//    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _fbo);
    
    assert(!glGetError());
    [[self openGLContext] flushBuffer];
}

@end
