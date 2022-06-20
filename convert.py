# Convert shadertoy shaders to glsl fragment shaders 

import re

def convert(input_file, output_file):
    with open(f'shaders/{input_file}', 'r') as f:
        data = ''.join(f.readlines())

    data = re.sub('iResolution', 'resolution', data)
    data = re.sub('iTime', 'time', data)
    data = re.sub('mainImage\( out vec4 fragColor, in vec2 fragCoord \)', 'main()', data)
    data = re.sub('fragCoord', 'gl_FragCoord.xy', data)
    
    # texture channels
    # data = re.sub('ground.mat.color', '//ground.mat.color', data)
    # data = re.sub("col = texture\(iChannel0, [a-zA-Z0-9() _+\*\-=\[\];',.\/]*", 'col = vec4(0);', data)
    data = re.sub('iChannel0', 'skybox', data)
    data = re.sub('iChannel1', 'tex1', data)

    extra = """#version 430

in vec4 vertexPos;
out vec4 fragColor;

uniform vec2 resolution;
uniform float time;
uniform sampler2D tex1;
uniform samplerCube skybox;

"""
    data = extra + data

    with open(f'shaders/{output_file}', 'w') as f:
        f.write(data)


#########################################
if __name__=='__main__':
    input_file  = 'shadertoy.glsl'
    output_file = 'fragment_raytrace.glsl'
    convert(input_file, output_file)