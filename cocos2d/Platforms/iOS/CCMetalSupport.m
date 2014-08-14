/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2013-2014 Cocos2D Authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "CCMetalSupport_Private.h"

#if __CC_METAL_SUPPORTED_AND_ENABLED

@implementation CCMetalContext

-(instancetype)init
{
	if((self = [super init])){
		_device = MTLCreateSystemDefaultDevice();
		_commandQueue = [_device newCommandQueue];
		_currentCommandBuffer = [_commandQueue commandBuffer];
	}
	
	return self;
}

NSString *CURRENT_CONTEXT_KEY = @"CURRENT_CONTEXT_KEY";

+(instancetype)currentContext
{
	return [NSThread currentThread].threadDictionary[CURRENT_CONTEXT_KEY];
}

+(void)setCurrentContext:(CCMetalContext *)context
{
	if(context){
		[NSThread currentThread].threadDictionary[CURRENT_CONTEXT_KEY] = context;
	} else {
		[[NSThread currentThread].threadDictionary removeObjectForKey:CURRENT_CONTEXT_KEY];
	}
}

-(void)setDestinationTexture:(id<MTLTexture>)destinationTexture
{
	if(_destinationTexture != destinationTexture){
		MTLRenderPassColorAttachmentDescriptor *colorAttachment = [MTLRenderPassColorAttachmentDescriptor new];
		colorAttachment.texture = destinationTexture;
		colorAttachment.loadAction = MTLLoadActionClear;
		colorAttachment.clearColor = MTLClearColorMake(0, 0, 0, 0);
		colorAttachment.storeAction = MTLStoreActionStore;

		MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
		renderPassDescriptor.colorAttachments[0] = colorAttachment;

		_currentRenderCommandEncoder = [self.currentCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
		_destinationTexture = destinationTexture;
	}
}

-(void)prepareCommandBuffer
{
	_currentCommandBuffer = [_commandQueue commandBuffer];
	_currentCommandBuffer.label = @"Main Cocos2D Command Buffer";
}

-(void)commitCurrentCommandBuffer
{
	[_currentCommandBuffer commit];
	_currentCommandBuffer = nil;
}

@end


@implementation CCGraphicsBufferMetal {
	@public
	id<MTLBuffer> _buffer;
}

-(instancetype)initWithCapacity:(NSUInteger)capacity elementSize:(size_t)elementSize type:(CCGraphicsBufferType)type;
{
	if((self = [super initWithCapacity:capacity elementSize:elementSize type:type])){
		// Use write combining? Buffers are already write only for the GL renderer.
		_buffer = [[CCMetalContext currentContext].device newBufferWithLength:capacity*elementSize options:MTLResourceOptionCPUCacheModeDefault];
		
		_ptr = _buffer.contents;
	}
	
	return self;
}

-(void)destroy {}

-(void)resize:(size_t)newCapacity;
{
	id<MTLBuffer> newBuffer = [[CCMetalContext currentContext].device newBufferWithLength:newCapacity*_elementSize options:MTLResourceOptionCPUCacheModeDefault];
	memcpy(newBuffer.contents, _ptr, _capacity*_elementSize);
	
	_capacity = newCapacity;
	_buffer = newBuffer;
	_ptr = _buffer.contents;
}

-(void)prepare;
{
	_count = 0;
}

-(void)commit; {}

@end


@implementation CCRenderCommandDrawMetal

static const MTLPrimitiveType MetalDrawModes[] = {
	GL_TRIANGLES,
	GL_LINES,
};

-(void)invokeOnRenderer:(CCRenderer *)renderer
{
	id<MTLRenderCommandEncoder> renderEncoder = [CCMetalContext currentContext].currentRenderCommandEncoder;
	CCGraphicsBufferMetal *indexBuffer = (CCGraphicsBufferMetal *)renderer->_elementBuffer;
	
	[renderEncoder pushDebugGroup:@"CCRendererCommandDraw: Invoke"];
	[renderer setRenderState:_renderState];
	[renderEncoder drawIndexedPrimitives:MetalDrawModes[_mode] indexCount:_count indexType:MTLIndexTypeUInt16 indexBuffer:indexBuffer->_buffer indexBufferOffset:2*_first];
	[renderEncoder popDebugGroup];
}

@end

#else

// Temporary
#warning Metal disabled

#endif
