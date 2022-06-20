from turtle import width
import moderngl_window as mglw

from convert import convert
from PIL import Image


FRAGMENT_SHADER = 'fragment_raytrace.glsl'


class App(mglw.WindowConfig):
    width = 1200
    height = int(width*9/16)
    window_size = (width, height)
    resource_dir = 'shaders'

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.quad = mglw.geometry.quad_fs()
        self.prog = self.load_program(
            vertex_shader='vertex.glsl',
            fragment_shader=FRAGMENT_SHADER
        )
        self.set_uniform('resolution', self.window_size)
        
        self.index = 0
        self.set_texture('images/marbles.jpg')
        self.set_texture('images/tiles.jpg')
        self.set_cubemap('alley')
        # self.set_cubemap_single('rock')

    def set_uniform(self, u_name, u_value):
        try:
            self.prog[u_name] = u_value
        except KeyError:
            print(f'uniform: {u_name} not used in shader')

    def set_texture(self, filename):
        img = Image.open(filename)
        texture = self.ctx.texture(img.size, 3, img.tobytes())
        texture.build_mipmaps()
        texture.anisotropy = 16.0
        texture.use(self.index)
        self.set_uniform(f'tex{self.index+1}', self.index)
        self.index += 1
    
    def set_cubemap_single(self, name):
        img = Image.open(f'cubemaps/single/{name}.png')
        width = img.size[0]
        s = int(width/4)
        data = b''
        data += img.crop((2*s,s,3*s,2*s)).tobytes()
        data += img.crop((0,s,s,2*s)).tobytes()

        data += img.crop((s,0,2*s,s)).tobytes()
        data += img.crop((s,2*s,2*s,3*s)).tobytes()

        data += img.crop((s,s,2*s,2*s)).tobytes()
        data += img.crop((3*s,s,4*s,2*s)).tobytes()

        cubemap = self.ctx.texture_cube((s,s), 4, data)
        cubemap.anisotropy = 16.0
        cubemap.use(self.index)
        self.set_uniform('skybox', self.index)
        self.index += 1

    def set_cubemap(self, name):
        img1 = Image.open(f'cubemaps/{name}/img1.jpg')
        img2 = Image.open(f'cubemaps/{name}/img2.jpg')
        img3 = Image.open(f'cubemaps/{name}/img3.jpg')
        img4 = Image.open(f'cubemaps/{name}/img4.jpg')
        img5 = Image.open(f'cubemaps/{name}/img5.jpg')
        img6 = Image.open(f'cubemaps/{name}/img6.jpg')
        
        data = img1.tobytes() + img2.tobytes() + \
               img3.tobytes() + img4.tobytes() + \
               img5.tobytes() + img6.tobytes()
        cubemap = self.ctx.texture_cube(img1.size, 3, data)
        cubemap.anisotropy = 16.0
        cubemap.use(self.index)
        self.set_uniform('skybox', self.index)
        self.index += 1
    
    def render(self, time: float, frame_time: float):
        self.ctx.clear()
        self.set_uniform('time', time)
        self.quad.render(self.prog)


if __name__ == '__main__':
    input_file  = 'shadertoy.glsl'
    output_file = 'fragment_raytrace.glsl'
    convert(input_file, output_file)

    mglw.run_window_config(App)