#version 430

in vec4 vertexPos;
out vec4 fragColor;

uniform vec2 resolution;
uniform float time;
uniform sampler2D tex1;
uniform samplerCube skybox;

// Hey!
// This is my implementation of raytracing including
// different reflections and refractions techniques 
// along with phong lighting model and shadows
// There are still some bugs I think :o but 
// I'll come to them a bit later!
// Enjoy :)


#define PI 3.1415926535
#define SHADOWS

float FLOAT_MAX = 10e+10;
float FLOAT_MIN = -10e+10;

// Global Parameters
vec4 ambientLight = vec4(1,1,1,1);
float ambientStrength = 0.1;
const int R = 3;    // Num reflections
const float delta = 10e-5;
float shadowFactor = 0.1;
const int N = 6;    // Num spheres
bool transform = true;
bool deg = false;
float fov = 0.8;   // 0 < fov
const int totalRays = int(pow(2.0, float(R)));

//--------------------------------------//

struct Material{
    vec4 color;
    float kd;   // Diffuse factor
    float ks;   // Diffuse factor
    float kr;   // Reflectivity
    float kt;   // Transmitivity
    float n;    // Refractive index
};

struct Sphere{
    float radius;
    vec3 center;
    Material mat;
};

struct Plane{
    vec3 center;
    vec3 size;
    vec3 normal;
    Material mat;
};

struct Light{
    vec3 dir;
    float mag;
    vec4 color;
    vec3 ray;
};

struct Ray{
    vec3 dir;
    vec3 origin;
    float factor;   // color multiplier for ray
    float n;    // index of medium ray in currently in
};

struct Hit{
    float d;
    vec3 point;
    vec3 normal;
};

mat3 Rotation(vec3 euler, bool deg){

    // Deg to Rad
    if (deg)
        euler *= PI / 180.0;

    // Rotation around X - pitch
    float c = cos(euler.x);
    float s = sin(euler.x);
    mat3 Rx = mat3(
        vec3(1, 0, 0),
        vec3(0, c, -s),
        vec3(0, s, c)
    );

    // Rotation around Y - yaw
    c = cos(euler.y);
    s = sin(euler.y);
    mat3 Ry = mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );

    // Rotation around Z - roll
    c = cos(euler.z);
    s = sin(euler.z);
    mat3 Rz = mat3(
        vec3(c, -s, 0),
        vec3(s, c, 0),
        vec3(0, 0, 1)
    );
    
    return Rz*Ry*Rx;
}

// Global variables
Ray[totalRays+1] reflectionRays;
Ray[totalRays+1] refractionRays;
Light light;
Plane ground;
Sphere[N] spheres;


// Raycasting Functions definition
Hit RayCastPlane(vec3 rayOrigin, vec3 rayDir, in Plane plane, float delta){
    Hit hit = Hit(-1.0, vec3(0), vec3(0));
    // Move hitpoint by delta to avoid 'acne'
    rayOrigin += delta * plane.normal;
 
    if (rayDir.y != 0.0){
        hit.d = (plane.center.y - rayOrigin.y)/rayDir.y;
        hit.point = rayOrigin + hit.d * rayDir;
        hit.normal = plane.normal;
        
        // Chceck if hitpoint within plane
        vec3 relPoint = abs(hit.point - plane.center);
        if (relPoint.x > plane.size.x || relPoint.z > plane.size.z){
            hit.d = -1.0;
        }
    }
    return hit;
}

Hit RayCastSphere(vec3 rayOrigin, vec3 rayDir, in Sphere sphere){
    Hit hit = Hit(-1.0, vec3(0), vec3(0));
    
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, rayOrigin-sphere.center);
    float c = dot(rayOrigin-sphere.center, rayOrigin-sphere.center) - 
                sphere.radius * sphere.radius;
    
    float det = b*b - 4.0*a*c;
    if (det >= 0.0){
        float d1 = (-b-sqrt(det))/2.0*a;
        float d2 = (-b+sqrt(det))/2.0*a;
        hit.d = min(d1,d2);
        hit.point = rayOrigin + hit.d * rayDir;
        hit.normal = normalize(hit.point - sphere.center);
    }
    return hit;
}

float RandFloat(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec4 GetLighting(in Material mat, in vec3 normal, in vec3 rayDir, in Light light){
    // Diffuse
    float diff = max(dot(normal, -light.dir), 0.0);
    // Specular
    vec3 reflectDir = -light.dir - 2.0 * normal * dot(-light.dir, normal);
    float spec = pow(max(dot(rayDir, reflectDir), 0.0), mat.ks); 
    // Total
    vec4 col = mat.color * light.color * (diff * mat.kd + spec * mat.kr);
    return col;
}

float Fresnel(float n1, float n2, vec3 normal, vec3 incident, float reflectivity){
    // Schlick aproximation
    float r0 = (n1-n2) / (n1+n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    if (n1 > n2)
    {
        float n = n1/n2;
        float sinT2 = n*n*(1.0-cosX*cosX);
        // Total internal reflection
        if (sinT2 > 1.0)
            return 1.0;
        cosX = sqrt(1.0-sinT2);
    }
    float x = 1.0-cosX;
    float ret = r0+(1.0-r0)*x*x*x*x*x;

    // adjust reflect multiplier for object reflectivity
    ret = (reflectivity + (1.0-reflectivity) * ret);
    return ret;
}


vec4 RayTraceCore(inout Ray ray, inout Material hitMat, inout Hit hit, in int iter){
    
    // Plane distance calculations
    Hit hitGround = RayCastPlane(ray.origin, ray.dir, ground, 0.0);
    // Sphere distance calculations
    Hit[N] hitSphere;
    for (int i=0; i<N; i++){
        hitSphere[i] = RayCastSphere(ray.origin, ray.dir, spheres[i]);
    }

    // Finding closest object to camera
    vec4 col = vec4(0,0,0,0);
    // Minimum distance for ground plane
    if (hitGround.d > 0.0){
        hit = hitGround;
        // sample ground texture
        vec2 groundTexScale = vec2(0.5);
        ground.mat.color = texture(tex1, hitGround.point.xz*groundTexScale);
        hitMat = ground.mat;
        col = GetLighting(ground.mat, hitGround.normal, ray.dir, light);
    }
    // Minimum distances for all spheres
    for (int i=0; i<N; i++){
        if (hitSphere[i].d < 0.0) hitSphere[i].d = FLOAT_MAX;
        if (hitSphere[i].d < hit.d){
            hit = hitSphere[i];
            hitMat = spheres[i].mat;
            col = GetLighting(spheres[i].mat, hitSphere[i].normal, ray.dir, light);
        }
    }

    // If no object hit then exit
    if (hit.d == FLOAT_MAX){
        col = texture(skybox, reflect(ray.dir, hit.normal));
        return col;
    }

    // Shadow of ground plane calculation
#ifdef SHADOWS
    Hit hitShadow;
    float minShadowDist = FLOAT_MAX;
    hitShadow = RayCastPlane(hit.point, -light.dir, ground, delta);
    if (hitShadow.d >= 0.0 && hitShadow.d < minShadowDist){
        col = vec4(0) * shadowFactor * exp(-1.0/hitShadow.d);
        minShadowDist = hitShadow.d;
    }
    // Shadows of all spheres calculation
    for (int i=0; i<N; i++){
        hitShadow = RayCastSphere(hit.point + delta*hit.normal, -light.dir, spheres[i]);
        if (hitShadow.d >= 0.0 && hitShadow.d < minShadowDist){
            minShadowDist = hitShadow.d;
            col = hitMat.color * shadowFactor * exp(-1.0/hitShadow.d);
        }
    }
#endif

    // Ambient light
    if (iter == 0)
        col += ambientStrength * ambientLight * hitMat.color;

    return col;
}


vec4 CastRays(in int iter){
    
    int startIdx = 0;
    if (iter != 0)
        startIdx = 1;
        for(int i=0;i<iter-1;i++)
            startIdx *= 2;
    int endIdx = 1;
    for(int i=0;i<iter;i++)
        endIdx *= 2;
    
    vec4 currLevelCol = vec4(0);

    // ------- REFLECTION PART -------
    // For each new reflection ray
    int j = 0;  // new ray counter
    for (int r=startIdx; r<endIdx; r++){
        // Incident ray
        Ray ray = reflectionRays[r];
        if (ray.dir == vec3(0) || ray.factor==0.0){
            // Rays that don't exist
            j += 1;
            continue;
        }

        Hit hit = Hit(FLOAT_MAX, vec3(0), vec3(0));
        Material hitMat;
        // Get color of ray
        vec4 col = RayTraceCore(ray, hitMat, hit, iter);
        currLevelCol += col * ray.factor;

        float n1, n2;
        if (ray.n != 1.0){
            n1 = ray.n;
            n2 = 1.0;
            hit.normal *= -1.0;
        } 
        else {
            n1 = 1.0;
            n2 = hitMat.n;
        }
        float Kr = Fresnel(n1, n2, hit.normal, ray.dir, hitMat.kr);
        
        // Add new reflection & refraction ray
        if (hit.d < FLOAT_MAX && hit.d > 0.0){
            // Add new reflection ray
            reflectionRays[endIdx+j].origin = hit.point + delta * hit.normal;
            reflectionRays[endIdx+j].dir = reflect(ray.dir, hit.normal);
            reflectionRays[endIdx+j].factor = ray.factor * Kr;
            reflectionRays[endIdx+j].n = n1;
            // Add new refraction ray
            if (hitMat.kt > 0.0){
                refractionRays[endIdx+j].origin = hit.point - delta * hit.normal;
                refractionRays[endIdx+j].factor = ray.factor * (1.0-Kr);
                refractionRays[endIdx+j].n = n2;
                refractionRays[endIdx+j].dir = refract(ray.dir, hit.normal, n1/n2);
            }
        }
        j += 1;
    }


    // ------- REFRACTION PART -------
    // For each new refraction ray
    for (int r=startIdx; r<endIdx; r++){
        Ray ray = refractionRays[r];
        if (ray.dir == vec3(0) || ray.factor==0.0){
            // Rays that don't exist
            j += 1;
            continue;
        }

        Hit hit = Hit(FLOAT_MAX, vec3(0), vec3(0));
        Material hitMat;
        // Get color of ray
        vec4 col = RayTraceCore(ray, hitMat, hit, iter);
        currLevelCol += col * ray.factor;

        float n1, n2;
        if (ray.n != 1.0){
            n1 = ray.n;
            n2 = 1.0;
            hit.normal *= -1.0;
        }
        else {
            n1 = 1.0;
            n2 = hitMat.n;
        }
        float Kr = Fresnel(n1, n2, hit.normal, ray.dir, hitMat.kr);
        
        // Add new reflection & refraction ray
        if (hit.d < FLOAT_MAX && hit.d > 0.0){
            // Add new reflection ray
            reflectionRays[endIdx+j].origin = hit.point + delta * hit.normal;
            reflectionRays[endIdx+j].dir = reflect(ray.dir, hit.normal);
            reflectionRays[endIdx+j].factor = ray.factor * Kr;
            reflectionRays[endIdx+j].n = n1;
            // Add new refraction ray
            if (hitMat.kt > 0.0){
                refractionRays[endIdx+j].origin = hit.point - delta * hit.normal;
                refractionRays[endIdx+j].factor = ray.factor * (1.0-Kr);
                refractionRays[endIdx+j].n = n2;
                refractionRays[endIdx+j].dir = refract(ray.dir, hit.normal, n1/n2);
            }
        }
        j += 1;
    }

    return currLevelCol;
}


//--------- Main Function ---------
void main()
{       
    // Camera
    vec3 cameraPos = vec3(0,0,-fov);
    Ray ray;
    ray.origin = cameraPos;
    
    // Camera motion
    vec3 camOffset = vec3(0, 2, 5);
    float camAngle = time * 0.6;
    float camRadius = 6.0;
    
    // Light
    light.dir = vec3(sin(time*0.7), -1, cos(time*0.7));
    //light.dir = vec3(-0.4, -1.0, -1);
    //light.dir = vec3(0.6, -0.5, 1);
    light.mag = 1.0;
    light.color = vec4(1,1,1,1);
    
    // Ground plane
    ground.center = vec3(camOffset.x,0,camOffset.z);
    ground.size = vec3(5,0,5);
    ground.normal = vec3(0,1,0);
    ground.mat = Material(vec4(0.3,0.8,0.2,1.0), 1.0, 16.0, 0.2, 0.0, 1.0);
    
    // Ground plane
    spheres[0].radius = 0.8;
    spheres[0].center = vec3(0.0,0.8,2);
    spheres[0].mat = Material(vec4(0,0,0,0.0), 1.0, 32.0, 0.1, 1.0, 1.25);

    spheres[1].radius = 1.1;
    spheres[1].center = vec3(1.0,1.1,6);
    spheres[1].mat = Material(vec4(0.3,0.3,1.0,1.0), 1.0, 16.0, 0.1, 0.0, 2.0);
    
    spheres[2].radius = 0.5;
    spheres[2].center = vec3(-2.0,0.5,3.0);
    spheres[2].mat = Material(vec4(0.8,0.8,0.1,1.0), 1.0, 32.0, 1.0, 0.0, 2.0);
    
    spheres[3].radius = 0.5;
    spheres[3].center = vec3(1.5,0.8,3);
    spheres[3].mat = Material(vec4(0.0,1.0,1.0,1.0), 1.0, 0.0001, 0.0, 0.0, 2.0);

    spheres[4].radius = 1.0;
    spheres[4].center = vec3(-0.8,1,4);
    spheres[4].mat = Material(vec4(1.0,0.1,0.1,1.0), 1.0, 16.0, 0.5, 0.0, 2.0);
    
    spheres[5].radius = 1.0;
    spheres[5].center = vec3(-2.0,1.0,7);
    spheres[5].mat = Material(vec4(0,0,0,0.0), 1.0, 32.0, 0.1, 1.0, 1.5);
    
    //------------------------------------------------------------//
    
    // CALCULATIONS BEGIN
    light.dir = normalize(light.dir);
    light.ray = light.dir * light.mag;
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (gl_FragCoord.xy-0.5*resolution.xy)/resolution.y;
    
    // View ray
    ray.dir = normalize(vec3(cameraPos.x+uv.x, cameraPos.y+uv.y, 0) - cameraPos);
    ray.factor = 1.0;
    ray.n = 1.0;    // Starts in air

    // Translate & Rotate camera
    camAngle = mod(camAngle, 2.0*PI);
    vec3 rotate = vec3(-0.2, camAngle, 0);
    vec3 translate = camOffset + vec3(camRadius*sin(camAngle), 0, -camRadius*cos(camAngle));
    if (!transform){
        rotate = vec3(0, 0, 0);
        translate = vec3(0,1,-1);
    }
    mat3 Rxyz = Rotation(rotate, deg);
    ray.dir = Rxyz * ray.dir;
    ray.origin = translate;
    
    // Start recurive raytracing
    for (int i=0; i<totalRays+1; i++){
        reflectionRays[i] = Ray(vec3(0), vec3(0), 0.0, 0.0);
        refractionRays[i] = Ray(vec3(0), vec3(0), 0.0, 0.0);
    }
    reflectionRays[0] = ray;
    vec4 finalCol = vec4(0);
    for(int iter=0; iter<R; iter++)
        finalCol += CastRays(iter);
    
    // Output to screen
    fragColor = finalCol;
}