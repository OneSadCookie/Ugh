#import <glm.hpp>

#import <OpenGL/gl3.h>

#import "UGHGLView.h"

@implementation UGHGLView

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:(NSOpenGLPixelFormatAttribute[]) {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0,
    }];

    self = [super initWithFrame:frameRect pixelFormat:format];
    if (!self) return nil;
    
    glm::vec2 v(1.0f, 2.0f);
    
    NSLog(@"hi!");
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    [[self openGLContext] flushBuffer];
}

@end
