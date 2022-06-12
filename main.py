from OpenGLContext import testingcontext
BaseContext = testingcontext.getInteractive()

from OpenGL.GL import *
from OpenGL.arrays import vbo
from OpenGLContext.arrays import *
from OpenGL.GL import shaders

import numpy as np


class TestContext(BaseContext):
    """Creates a simple vertex shader..."""
    def OnInit( self ):
        with open('shaders/vertex.glsl','r') as f:
            content = f.readlines()
            VERTEX_SHADER = shaders.compileShader(content, GL_VERTEX_SHADER)

        with open('shaders/fragment.glsl','r') as f:
            content = f.readlines()
            FRAGMENT_SHADER = shaders.compileShader(content, GL_FRAGMENT_SHADER)

        self.shader = shaders.compileProgram(VERTEX_SHADER,FRAGMENT_SHADER)

        self.vertices = np.array(
            [
                [-0.5, -0.5, 0.0, 1.0, 0, 0],
                [0.5, -0.5, 0.0, 0, 1.0, 0],
                [0.0, 0.5, 0.0, 0, 0, 1.0],
            ], np.float32)
        self.vbo = vbo.VBO(self.vertices)
        

    def Render(self, mode):
        """Render the geometry for the scene."""
        BaseContext.Render( self, mode)
        shaders.glUseProgram(self.shader)
        try:
            self.vbo.bind()
            try:
                glEnableClientState(GL_VERTEX_ARRAY)
                glEnableClientState(GL_COLOR_ARRAY)
                glVertexPointer(3, GL_FLOAT, 24, self.vbo)
                glColorPointer(3, GL_FLOAT, 24, self.vbo+12)
                glDrawArrays(GL_TRIANGLES, 0, 9)
            finally:
                self.vbo.unbind()
                glDisableClientState(GL_VERTEX_ARRAY)
                glDisableClientState(GL_COLOR_ARRAY)
        finally:
            shaders.glUseProgram( 0 )


if __name__ == "__main__":
    TestContext.ContextMainLoop()