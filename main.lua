--castle://localhost:4000/vox.castle

if CASTLE_PREFETCH then
    CASTLE_PREFETCH({
        'lib/list.lua',
        'lib/cpml/modules/vec3.lua',
        'lib/cpml/modules/vec2.lua',
        'lib/cpml/modules/utils.lua',
        'lib/cpml/modules/mat4.lua',
        'lib/cpml/modules/quat.lua',
        'lib/cpml/modules/constants.lua',
        'lib/cpml/init.lua',
        'img/rotate-camera.png'
    })
end

print("Prefetch complete")

local VIEWPORT_SIZES = {
  
  --1
  {
    x = 200,
    y = 50,
    w = 280,
    h = 280
  },
  
  --2
  {
    x = 200,
    y = 24,
    w = 380,
    h = 380
  },
  
  
  --3
  {
    x = 200,
    y = 5,
    w = 410,
    h = 410,
  }

}

local cpml = require("lib/cpml")
local mat4 = cpml.mat4;
local vec3 = cpml.vec3;
local vec2 = cpml.vec2;
local ui = castle.ui;
local List = require("lib/list");

print("Requires Done");

local state = {
  
}

function headLook(out, eye, look_at, up)
	local z_axis = (look_at - eye):normalize()
	local x_axis = z_axis:cross(up):normalize()--up:cross(z_axis):normalize() * vec3(-1, -1, -1);  
	local y_axis = x_axis:cross(z_axis):normalize()
 
  out[1] = x_axis.x
	out[2] = x_axis.y
	out[3] = x_axis.z
	out[4] = 0
	out[5] = y_axis.x
	out[6] = y_axis.y
	out[7] = y_axis.z
	out[8] = 0
	out[9] = z_axis.x
	out[10] = z_axis.y
	out[11] = z_axis.z
	out[12] = 0
	out[13] = eye.x
	out[14] = eye.y
	out[15] = eye.z
	out[16] = 1

  return out
end

local client = love;


function renderAllLayers(grid)

  for z = 1, grid.depth do
    renderLayer(grid, z)
  end
  
end

function adjustViewport()
  
  local offsetX = 200;
  
  state.ui.viewport = VIEWPORT_SIZES[state.options.canvasSize];
  state.ui.cambutton = {
    y = state.ui.viewport.y + 5,
    x = state.ui.viewport.x + 5,
    w = 32,
    h = 32
  }
  handleResize();

end

function renderLayer(grid, z)

  local layer = grid.voxels[z];
  love.graphics.setBlendMode("replace", "premultiplied");  
  local w, h = grid.width, grid.height;

  --Per Layer
  --[[
  love.graphics.setCanvas(layer.gpu);
  for x = 1,w do
  for y = 1,h do
    
    love.graphics.setColor(layer[x][y]);
    love.graphics.rectangle("fill", x-1, y-1, 1, 1);
  end end
    
  love.graphics.setCanvas()
  ]]
  
  --Tiled
  love.graphics.setCanvas(grid.gpu);
  
  
  for x = 1,w do
  for y = 1,h do
    love.graphics.setColor(layer[x][y]);
    love.graphics.rectangle("fill", x-1, (z-1) * grid.height + y-1, 1, 1);
   end end
  
  
 -- love.graphics.setColor(1,1,1,1);
  --love.graphics.draw(layer.gpu, 0, (z-1) * 16);
  
  love.graphics.setCanvas();
  love.graphics.setBlendMode("alpha");
  
  state.dirtyVoxels = true;
  
end


function clearGrid(grid) 
  
  local w, h = grid.width, grid.height;
  
  grid.gpu = love.graphics.newCanvas(grid.width, grid.height * grid.depth, {dpiscale=1});
  grid.gpu:setWrap("clampzero", "clampzero");
  grid.gpu:setFilter("nearest", "nearest");
  
  grid.voxels = {};
  
  for z = 1,grid.depth do
    
    grid.voxels[z] = {};
    
    local size = grid.width * grid.height;
    local layer = grid.voxels[z];
    
    for x = 1,w do
      layer[x] = {};
    for y = 1,h do
    
    --[[
      if (math.random() < 0.1 and y < 17) then
        layer[x][y] = {
          math.random(),math.random(),math.random(),1
        }
      else
        layer[x][y] = {
         0,0,0,0
        }
      end
      ]]
      
      layer[x][y] = {
        0,0,0,0
      }
      
      local dist = vec3.dist(vec3(x, y, z), vec3(8, 12, 8.5));
      local c = state.color;
      
      if y == grid.height then
        layer[x][y] = {c[1], c[2], c[3], c[4]};
      end
      --[[
      if dist < 3 then
        layer[x][y] = {0.3, 0.8, 0.2, 1.0}
      end
      ]]
      
    end
    end
    
    renderLayer(grid, z);

  end
  
  state.camTarget = vec3(state.grid.width * 0.5, state.grid.height * 0.5 + 1.0, state.grid.depth * 0.5);
  
  updateCamera3D(0,0);
end


function makeQuad()
  local vertices = {
		{
			0, 0, 
			0, 0,
			1, 1, 1,
		},
		{
			1, 0,
			1, 0, 
			1, 1, 1
		},
		{
			1, 1,
			1, 1,
			1, 1, 1
		},
		{
			0, 1,
			0, 1,
			1, 1, 1
		},
    }
        
    return love.graphics.newMesh(vertices, "fan", "static")
end

function makeShaders()

  local vert = [[    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        return transform_projection * vertex_position;
    }
  ]];
  
  local trace = [[
    extern Image grid_1;
    uniform float gridDim;
    uniform int pickMode;
    uniform mat4 headMatrix;

    vec4 sampleGrid(vec3 pos)
    {
      float z = pos.z;
      
      if (z < 0.0 || z >= gridDim || pos.x < 0.0 || pos.x >= gridDim || pos.y < 0.0 || pos.y >= gridDim) {
        return vec4(0.0);
      }      
      
      float layer = floor(z);
      
      vec2 uv;
      uv.x = (floor(pos.x) + 0.5) / gridDim;
      uv.y = (floor(pos.y + layer * gridDim) + 0.5) / (gridDim * gridDim);   
      
      return Texel(grid_1, uv);
    
    }
    
    
    float dc(float v, float d) {
      
      float t;
      if (d > 0.0) {
        t = (ceil(v) - v) / d;
      } else if (d < 0.0) {
        t =  abs(fract(v) / d);
      } else {
        t = 100.0;
      }
       
      return t;
    }
    
    //Advance ray into next unit cell
    vec3 advance(vec3 pos, vec3 dir, out vec3 normal) {
      
      vec3 ds = vec3(dc(pos.x, dir.x), dc(pos.y, dir.y), dc(pos.z, dir.z));
      float t = min(ds.z, min(ds.x, ds.y));
       
      if (ds.x < ds.y && ds.x < ds.z) {
        normal = vec3(-sign(dir.x), 0.0, 0.0);
      } else if (ds.y < ds.z) {
        normal = vec3(0.0, -sign(dir.y), 0.0);
      } else {
        normal = vec3(0.0, 0.0, -sign(dir.z));
      }
             
       return (pos + dir * (t + 0.001));
    }
    
    vec3 getNormal(vec3 pos, vec3 dir) {
      vec3 center = floor(pos) + vec3(0.5);
      
      vec3 d = pos - center;
      
      vec3 ad = abs(d);
      
      if (ad.x > ad.y && ad.x > ad.z) {
        d.y = 0.0;
        d.z = 0.0;
      } else if (ad.y > ad.z) {
        d.x = 0.0;
        d.z = 0.0;
      } else {
        d.x = 0.0;
        d.y = 0.0;
      }
      
      return normalize(d);
      
    }
    
    vec4 trace(vec3 origin, vec3 dir, out vec3 pos, out vec3 normal, out bool hit, int tMax) {
      
      pos = origin + dir * 0.001;
      
      for (int i = 0; i < tMax; i++) {
        vec4 sample = sampleGrid(pos);  
        
        if (sample.a > 0.1) {
          //Double check normal
          vec3 p2 = pos + normal * 0.5;
          vec4 s2 = sampleGrid(p2);
          if (s2.a > 0.1) {
            p2 = pos - normal * 0.1;
            normal = getNormal(p2, dir);
          }
          
          hit = true;
          return sample;
        }
        pos = advance(pos, dir, normal);

      }
      
      /* Ground Plane
      if (dir.y > 0.0) {
          normal = vec3(0.0, -1.0, 0.0);
          pos = pos + dir * abs(pos.y / dir.y);
          hit = true;
          //return vec4(1.0, 1.0, 1.0, 1.0);
      }*/
      
      hit = false;
      return vec4(0.0);
    }
    
    void getHeadRay(in vec2 uv, out vec3 origin, out vec3 dir) {
      dir = vec3(uv * 2.0 - vec2(1.0), 1.0);
      //dir.x *= -0.5;
      //dir.y *= 0.5;
      dir.xy *= 0.5;
      dir = normalize(dir);
      dir = normalize((headMatrix * vec4(dir, 0.0)).xyz);        
      origin = headMatrix[3].xyz;
    }
            
  ]];
  
  local queryFrag = trace..[[
    
    uniform vec2 queryUV;
  
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
    
      vec3 origin,  dir;
      getHeadRay(queryUV, origin, dir);
      
      vec3 position, normal;
      bool hit;
      trace(origin, dir, position, normal, hit, 128);
      
      position = floor(position) + vec3(0.5);
      
      if (hit) {
        if (pickMode == 1) {
          return vec4((position + normal) / gridDim, 1.0);
        } else {
          return vec4(position / gridDim, 1.0);
        }
      }
      
      return vec4(0.0);

    }
  ]];
  
  local renderFrag = trace..[[    
    uniform vec3 lightDir;
    uniform vec3 sunColor;
    uniform vec3 skyColor;
    uniform bool showGrid;
    uniform float envScale;
    uniform int sampling;
    uniform vec2 viewportSize;
    uniform float reflectionScale;
    uniform float sunScale;
    
    vec4 getSkyColor(vec3 direction) 
    {
      
      float t = pow(dot(direction, lightDir) * 0.5 + 0.5, 2.0);
      t *= sunScale;
      
      return vec4(mix(skyColor, sunColor, t), 1.0);
    }

    #define PI 3.14159

    float randAngle (vec2 st) {
      return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123) * PI;
    }
    vec2 globalUV;

    void traceAO(in vec3 origin, in vec3 normal, inout vec3 outColor, float quality) {
      
      float weightSum = 0.0;
      vec3 color = vec3(0.0);

      if (envScale > 0.0) {
        vec3 randvec = normalize(vec3(normal.y, -normal.z, normal.x));
        vec3 tangent = normalize(randvec - dot(randvec, normal) * normal);
        mat3 aligned_mat = mat3(tangent, normalize(cross(normal, tangent)), normal);  
        
      
        float jitter = randAngle(globalUV);   
        float step = 1.0 / (quality * (sampling * 4.0) + 4.0);
          
          
          //Hemisphere integral
          for (float aa = 0.0; aa <= 1.0 - step; aa += step * 0.75) {
            for (float bb = 0.1 + jitter * 0.1; bb <= 1.0; bb += step) {

             vec3 ray = vec3(
                cos(aa * PI * 2 + jitter) * cos(bb * PI), 
                sin(aa * PI * 2 + jitter) * cos(bb * PI),
                sin(bb * PI)
              );
              
             vec3 direction = aligned_mat * ray;
             
             vec3 op, on;
             bool hit;
             
            vec4 sample = trace(origin, direction, op, on, hit, 1 + sampling);
            
            float weight = mix(1.0, dot(direction, normal), 0.5);
            
            vec3 envLight = getSkyColor(direction).rgb;//vec3(-direction.y * 0.1 + 0.9);
            envLight = mix(envLight, vec3(1.0, 1.0, 1.0), 0.5) * envScale * 2.0;
            
            //Ambient Light
            color += envLight * weight  * (1.0 - float(hit));
            //Bounce Light
            color += sample.rgb * weight * float(hit) * 0.25 * envScale * 2.0;

            weightSum += weight;

            }      
          }
          color /= weightSum;
          weightSum = 1.0;

        } else {
          weightSum = 1.0;
        }
        
        //Sun Light
        vec3 p2, n2;
        bool hit;
        trace(origin + lightDir * 0.01, lightDir, p2, n2, hit, 64);
        
        //float sunWeight = sunScale * 2.0;

       //weightSum += sunWeight;
       color += sunScale * 2.0 * vec3(0.95, 0.9, 0.8) * (1.0 - float(hit)) * max(0.0, dot(lightDir, normal));
        
        //color /= weightSum; 
        outColor += color;
    }
    
    float edgeLength(vec3 pos) {
      vec3 d = abs(pos - (floor(pos) + vec3(0.5)));
      return max(d.y + d.z, max(d.x + d.y, d.x + d.z));
    }
    
    vec4 raycast(vec3 origin, vec3 dir, out bool isEdge, out vec3 pos, out vec3 normal, out bool hit) {
 
        isEdge = false;
        
        vec4 color = trace(origin, dir, pos, normal, hit, 160);
        
        float hitDist = length(pos - origin);
        
        if (! hit) {
          return getSkyColor(dir);
        }
        
        isEdge = edgeLength(pos) > 0.97;

        
        //Diffuse Lighting
        vec3 aoColor = vec3(0.0);
        float aoQuality = clamp(1.0 - (hitDist / 20.0), 0.0, 1.0);
        traceAO(pos + normal * 0.001, normal, aoColor, aoQuality);
        
        color = vec4(aoColor, 1.0) * color;
        color.a = 1.0;
        
        if (isEdge && showGrid) {
          color = clamp(color, vec4(0.0), vec4(1.0));
          color.rgb = vec3(1.0) - color.rgb;
          color.rgb = mix(color.rgb, vec3(0.0), 0.2);
        }
        
        return color;    
    }
    
    
    vec4 raycastCamera(vec2 texture_coords, out bool isEdge)
    {
        globalUV = texture_coords;
    
        vec3 origin, dir;
        getHeadRay(texture_coords, origin, dir);
        
        vec3 pos, normal;
        bool hit;
        vec4 color = raycast(origin, dir, isEdge, pos, normal, hit);
        
        if (hit && reflectionScale > 0.0) {
          vec3 bounceDir = reflect(dir, normal);
          bool edge2;
          vec4 reflectionColor = raycast(pos + bounceDir * 0.01, bounceDir, edge2, pos, normal, hit);
          
          float spec = pow(max(0.0, dot(bounceDir, lightDir)), 10.0);

          color.rgb = mix(color.rgb, reflectionColor.rgb + vec3(spec), reflectionScale * 0.2);
        }
        
        return color;
    }
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
        bool isEdge = false;
        float aa = 0.5/viewportSize.x;
        
        vec4 clr = vec4(0.0);
        
        if (sampling < 2) {
          clr = raycastCamera(texture_coords, isEdge);
        } if (sampling == 2) {
          clr = raycastCamera(texture_coords + vec2(-aa * 0.5), isEdge);
          clr += raycastCamera(texture_coords + vec2(aa * 0.5), isEdge);
          clr *= 0.5;
        } else if (sampling == 4) {
          clr = raycastCamera(texture_coords, isEdge);
          clr += raycastCamera(texture_coords + vec2(aa, 0), isEdge);
          clr += raycastCamera(texture_coords + vec2(aa, aa), isEdge);
          clr += raycastCamera(texture_coords + vec2(0, aa), isEdge);
          clr *= 0.25;
        } else if (sampling > 4) {
          clr = raycastCamera(texture_coords, isEdge);
          clr += raycastCamera(texture_coords + vec2(aa, 0), isEdge);
          clr += raycastCamera(texture_coords + vec2(aa, aa), isEdge);
          clr += raycastCamera(texture_coords + vec2(0, aa), isEdge);
          
          clr += raycastCamera(texture_coords + vec2(-aa, aa), isEdge);
          clr += raycastCamera(texture_coords + vec2(-aa, 0), isEdge);
          clr += raycastCamera(texture_coords + vec2(-aa, -aa), isEdge);
          
          clr += raycastCamera(texture_coords + vec2(0, -aa), isEdge);
          clr += raycastCamera(texture_coords + vec2(aa, -aa), isEdge);
          clr /= 9.0;
        }
        
        clr.a = 1.0;
        return clr;
    }
  ]];
  
  return love.graphics.newShader(vert, renderFrag), love.graphics.newShader(vert, queryFrag);
  
end


local assets = {
  
  quadMesh = makeQuad(),

}


local tempHeadMat = mat4();
local tempLightDir = vec3();

local SAMPLING_QUALITY = {1, 2, 4, 6, 8};


local lastRenderTime = -1;
local lastRenderQuality = 1;

function renderVoxels(grid)
  local tStart = love.timer.getTime();
 
  local renderQuality = 1;
  
  if (not state.dirtyVoxels) then
    
    if (lastRenderQuality < state.options.quality and tStart - lastRenderTime > 0.1) then     
      renderQuality = state.renderQuality;
    else
        return
    end
  end
  
  if (state.forceQuality) then
    state.forceQuality = false;
    renderQuality = state.options.quality;
  end
  
  lastRenderTime = tStart;
  lastRenderQuality = renderQuality;

  state.dirtyVoxels = false;

  love.graphics.setCanvas(assets.renderCanvas);
  love.graphics.setColor({1,1,1,1});
  love.graphics.setShader(assets.renderShader);
  
  mat4.transpose(tempHeadMat, state.headMatrix);
  
  local pixelScale = love.window.getDPIScale();

  assets.renderShader:send("headMatrix", tempHeadMat);
  assets.renderShader:send("gridDim", grid.width);
  assets.renderShader:send("grid_1", grid.gpu);
  assets.renderShader:send("showGrid", state.options.showGrid);
  assets.renderShader:send("envScale", state.options.envScale);
  assets.renderShader:send("sampling", SAMPLING_QUALITY[renderQuality]);
  assets.renderShader:send("viewportSize", {state.ui.viewport.w * pixelScale, state.ui.viewport.h * pixelScale});
  assets.renderShader:send("reflectionScale", state.options.reflectionScale);
  assets.renderShader:send("envScale", state.options.envScale);
  assets.renderShader:send("sunScale", state.options.sunScale);
  assets.renderShader:send("sunColor", state.options.sunColor);
  assets.renderShader:send("skyColor", state.options.skyColor);
  
  local sa1 = state.options.sunAngle * math.pi * 2;
  local sa2 = state.options.sunIncline * math.pi * 0.5;
  
  tempLightDir.x = math.sin(sa1) * math.cos(sa2);
  tempLightDir.z = math.cos(sa1) * math.cos(sa2);
  tempLightDir.y = -math.sin(sa2);
    
  assets.renderShader:send("lightDir", {tempLightDir.x, tempLightDir.y, tempLightDir.z});
  
  local vp = state.ui.viewport;
  love.graphics.draw(assets.quadMesh, 0, 0, 0, vp.w, vp.h);

  love.graphics.setShader();
  love.graphics.setCanvas();
  
  --Force Flush:
  --local r,g,b,a = assets.renderCanvas:newImageData(1, 1, 0, 0, 1, 1):getPixel(0,0);
  
  --local tStop = love.timer.getTime();
  
 -- print("time:", (tStop - tStart) * 1000.0);
  
end


function drawGrid3D(grid)
  
  renderVoxels(grid);
  
  local vp = state.ui.viewport;
  love.graphics.setColor(1,1,1,1);
  
  love.graphics.draw(assets.renderCanvas, vp.x, vp.y, 0, 1, 1);
  
  love.graphics.setColor(state.color);
  love.graphics.setLineWidth(5);
  love.graphics.rectangle("line", vp.x, vp.y, vp.w, vp.h);
  
  
end

function drawImg(img, box)
  
   love.graphics.setColor(1,1,1,1);
  love.graphics.setShader();
    
  love.graphics.draw(assets.img.rotate, box.x, box.y, 0, box.w / img:getWidth(), box.h / img:getHeight());
  
end

function drawUI()
  
  love.graphics.setColor(1,1,1,1);
  love.graphics.setShader();
  
  drawImg(assets.img.rotate, state.ui.cambutton);
  
  
  --love.graphics.setColor(state.color); 
  --love.graphics.rectangle("fill", 0, 0, 20, 20);
  --love.graphics.setColor(1,1,1,1);
end

function handleResize(w, h)

  local vp = state.ui.viewport;
  assets.renderCanvas = love.graphics.newCanvas(vp.w, vp.h);
  state.dirtyVoxels = true;
  
end

function client.draw()
  
  --drawGrid2D(state.grid);
  drawGrid3D(state.grid);
  drawUI();
  
end

function client.wheelmoved(x, y)
  
  if (state.cameraMode == "orbit") then
    state.cameraZoom = cpml.utils.clamp(state.cameraZoom - y, 5.0, 60.0);
  end
  
  updateCamera3D(0,0);
  state.dirtyVoxels = true;
  
end

function contains(x, y, box)
  return x >= box.x and y >= box.y and x < box.x + box.w and y < box.y + box.h; 
end

function controlCamera(toggle)
  love.mouse.setRelativeMode(toggle);
  
  if (toggle ~= state.ui.cameraMode) then
    state.dirtyVoxels = true;
  end
  
  state.ui.cameraMode = toggle;

  state.renderQuality = state.options.quality;
  
  if (toggle) then
    state.renderQuality = 1;
  end
end

function client.mousepressed(x, y, button)
  
  if (contains(x, y, state.ui.cambutton)) then
    controlCamera(true);
    return;
  end
  
  
  if (button == 1) then
    edit3D(x, y);
  elseif (button == 2) then
    edit3D(x, y, "remove");
  elseif (button == 3) then
    controlCamera(true);
  end
 
end

function client.mousereleased(x, y, button)

  if (button == 3 or button == 1) then
    controlCamera(false);
  end

end

function client.mousemoved(x,y, dx, dy)
  
  --if (love.mouse.isDown(3)) then
  if (state.ui.cameraMode == true) then
    --print(state.ui.cameraMode);
    updateCamera3D(dx, dy);
  end
  --end
  
 
  
end


function updateScript(script, dt)

  local size = state.grid.width;
  
  for x = 1, size do
  for y = 1, size do
  for z = 1, size do
    
    r, g, b, a = script(love.timer.getTime(), x, z, y);
    state.grid.voxels[z][x][y] = {r, g, b, a};
    
  end end end
  
  renderAllLayers(state.grid);

end

function removeVoxel(grid, x, y, z)
  
  if (not grid.voxels[z]) or (not grid.voxels[z][x]) or (not grid.voxels[z][x][y]) then
    return;
  end
  
  grid.voxels[z][x][y] = {
    0, 0, 0, 0
  }
    
  renderLayer(grid, z);
  
end

local ColorUtil = {
  
  equals = function(a, b) 
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
  end,
  
  copy = function(a,b)
    a[1] = b[1];
    a[2] = b[2];
    a[3] = b[3];
    a[4] = b[4];
  end

}

function fillVoxel(grid, x, y, z, target)
  
  if (not grid.voxels[z]) or (not grid.voxels[z][x]) or (not grid.voxels[z][x][y]) then
    return;
  end
  
  
  local vc = grid.voxels[z][x][y];
  
  if (vc[4] == 0) then
    return
  end
  
  local color = state.color;
  
  if (ColorUtil.equals(vc, target)) then

    ColorUtil.copy(vc, color);
    
    fillVoxel(grid, x + 1, y, z, target);
    fillVoxel(grid, x - 1, y, z, target);
    fillVoxel(grid, x , y + 1, z, target);
    fillVoxel(grid, x , y - 1, z, target);
    fillVoxel(grid, x , y, z + 1, target);
    fillVoxel(grid, x , y, z - 1, target);
    
  end
end

function addVoxel(grid, x, y, z) 
  
  if (not grid.voxels[z]) or (not grid.voxels[z][x]) or (not grid.voxels[z][x][y]) then
    return;
  end
  

  local c = state.color;
  
  grid.voxels[z][x][y] = {
    c[1], c[2], c[3], c[4]
  }
    
  renderLayer(grid, z);

end


function edit3D(mx, my, toolOveride)

  local tool = toolOveride or state.tool;

  local vp = state.ui.viewport;
  
  local texCoord = {(mx - vp.x)/vp.w, (my - vp.y) / vp.h};
  
  if (texCoord[1] < 0 or texCoord[1] > 1) then
    return;
  end
  
  love.graphics.setCanvas(assets.queryCanvas);
  love.graphics.setColor(1,1,1,1);
  love.graphics.setBlendMode("replace", "premultiplied");  

  
  love.graphics.setShader(assets.queryShader);
  assets.queryShader:send("queryUV", texCoord);
  mat4.transpose(tempHeadMat, state.headMatrix);

  local grid = state.grid;
  
  assets.queryShader:send("headMatrix", tempHeadMat);
  assets.queryShader:send("gridDim", grid.width);
  assets.queryShader:send("grid_1", grid.gpu);
  
  local pickMode = 0;
  
  if (tool == "add") then
    pickMode = 1;
  end
  
  assets.queryShader:send("pickMode", pickMode);

  love.graphics.draw(assets.quadMesh, 0, 0, 1, 1);
  love.graphics.rectangle("fill", 0, 0, 1, 1);
  
  love.graphics.setCanvas();
  love.graphics.setShader();
  love.graphics.setBlendMode("alpha");  

  local r,g,b,a = assets.queryCanvas:newImageData(1, 1, 0, 0, 1, 1):getPixel(0,0);
  
  if (a < 0.1) then return end;

  local x, y, z = math.floor(r * grid.width) + 1, math.floor(g * grid.height) + 1, math.floor(b * grid.depth) + 1;
  
  saveSnapshot();
  
  if (tool == "add") then
    addVoxel(grid, x, y, z);
    state.forceQuality = true;
  elseif (tool == "remove") then
    removeVoxel(grid, x, y, z);
    state.forceQuality = true;
  elseif (tool == "pick color") then
    local pc = grid.voxels[z][x][y];
    state.color = {pc[1], pc[2], pc[3], pc[4]};
  elseif (tool == "fill") then
    local pc = grid.voxels[z][x][y];
    local vc = {};
    ColorUtil.copy(vc, pc);
    if(ColorUtil.equals(vc, state.color)) then return end;
    fillVoxel(grid, x, y, z, vc);
    renderAllLayers(grid);
    state.forceQuality = true;
  end
  
  
  
end

local tempCameraPosition = vec3();
function updateCamera3D(dx, dy)
  
  if (dx ~= 0.0 or dy ~= 0.0) then
    state.dirtyVoxels = true;
  end
  
  local cameraAngles = state.cameraAngles;
  
  local sensitivity = 0.01;
  
  if (state.cameraMode ~= 'orbit')  then
    sensitivity = sensitivity * 0.5;
  end
  
  cameraAngles.x = cameraAngles.x - dx * sensitivity;
  cameraAngles.y = cameraAngles.y - dy * sensitivity;
  cameraAngles.y = cpml.utils.clamp(cameraAngles.y, -math.pi * 0.45, math.pi * 0.45);

  tempCameraPosition.x = math.sin(cameraAngles.x) * math.cos(cameraAngles.y);
  tempCameraPosition.z = math.cos(cameraAngles.x) * math.cos(cameraAngles.y);
  tempCameraPosition.y = math.sin(cameraAngles.y);
  
  local target = state.camTarget;
  local up = vec3(0.0, 1.0, 0.0);

  if (state.cameraMode == 'orbit') then
    tempCameraPosition = tempCameraPosition:scale(state.cameraZoom) + target;
    headLook(state.headMatrix, tempCameraPosition, target, up);
  else
    tempCameraPosition.y = -tempCameraPosition.y;
    local headPos = vec3(state.headMatrix[13], state.headMatrix[14], state.headMatrix[15]); 
    local target = headPos + tempCameraPosition;
    
    headLook(state.headMatrix, headPos, target, up);
    
  end
end

function spinCamera(dt)
  local t = love.timer.getTime();
    
  --local eye = vec3(math.sin(t) * 20, 8.0, math.cos(t) * 20);
  local radius = 28.0;
   
  local target = vec3(8.0, 8.0, 8.0);

  local eye = vec3(math.sin(t) * radius, 0.0,  math.cos(t) * radius);
  
  eye = eye + target;
  local up = vec3(0.0, 1.0, 0.0);
  
  headLook(state.headMatrix, eye, target, up);

end

local dpiSave = -1;


function updateKeys(dt)

  local tempMat = mat4.identity();
  
  for i = 1,16 do
    tempMat[i] = state.headMatrix[i];
  end
  
  local yScale = 0.0;
  local speed = dt * state.cameraZoom * 0.5;

  if (state.cameraMode == "first person") then
    yScale = 1.0;
    speed = dt * 10.0;
  end
  
  tempMat[13] = 0.0;
  tempMat[14] = 0.0;
  tempMat[15] = 0.0;
  
  local moved = false;
  local dir = vec3(0.0, 0.0, 0.0);
  
  if (love.keyboard.isDown("w")) then
    dir = dir + tempMat * vec3(0.0, 0.0, 1.0);
    dir.y = dir.y * yScale;
    moved = true;
  end
  
  if (love.keyboard.isDown("s")) then
    dir = dir + tempMat * vec3(0.0, 0.0, -1.0);
    dir.y = dir.y * yScale;
    moved = true;
  end
  
  if (love.keyboard.isDown("a")) then
   dir = dir + tempMat * vec3(-1.0, 0.0, 0.0);
    dir.y = dir.y * yScale;
    moved = true;
  end
  
  if (love.keyboard.isDown("d")) then
    dir = dir + tempMat * vec3(1.0, 0.0, 0.0);
    dir.y = dir.y * yScale;
    moved = true;
  end
  
  if (love.keyboard.isDown("e")) then
    dir = vec3(0.0, -1.0, 0.0);
    moved = true;
  end
  
  if (love.keyboard.isDown("q")) then
    dir = vec3(0.0, 1.0, 0.0);
    moved = true;
  end
  
  if (moved) then
    dir = vec3.normalize(dir) * speed;
    state.dirtyVoxels = true;
    
    if (state.cameraMode == 'orbit') then
      state.camTarget = state.camTarget + dir;
    else
      state.headMatrix[13] = state.headMatrix[13] + dir.x;
      state.headMatrix[14] = state.headMatrix[14] + dir.y;
      state.headMatrix[15] = state.headMatrix[15] + dir.z;
    end
    
    updateCamera3D(0,0);
  end

end

function client.update(dt)
  
  if (dpiSave ~= love.window.getDPIScale()) then
    dpiSave = love.window.getDPIScale();
    w,h = love.graphics.getDimensions();
    handleResize(w, h);
  end
  
  updateKeys(dt);
  --spinCamera();
  
  --updatePaint2D();
  
  --[[
  updateScript(function(t, x, y, z) 
    
    local height = math.sin(x * 0.2 + t * 2.0) * 2 + math.cos(y * 0.2 + t * 2.0) * 2 + 10.0
    
    if ( z > height ) then
      return 1.0, 1.0 - z/16.0, 0.0, 1.0;
    else 
      return 0.0, 0.0, 0.0, 0.0;
    end
    
  end, dt)
  ]]
  
end

function saveSnapshot()
  
  
  local gs = {};
  
  local grid = state.grid;
  
  for z = 1, grid.depth do
    gs[z] = {};
  for x = 1, grid.width do
    gs[z][x] = {}
  for y = 1, grid.height do
    
    gs[z][x][y] = {};
    ColorUtil.copy(gs[z][x][y], grid.voxels[z][x][y])
  
  end end end
  
  
  List.pushright(state.snapshots, gs);
  
  if (List.length(state.snapshots) > 10) then
    List.popleft(state.snapshots);
  end
  
end

function loadSnapshot()
  
  if (List.length(state.snapshots) == 0) then
    return;
  end
  
  local gs = List.popright(state.snapshots);
  local grid = state.grid;
  
  for z = 1, grid.depth do
  for x = 1, grid.width do
  for y = 1, grid.height do
    
    ColorUtil.copy(grid.voxels[z][x][y], gs[z][x][y])
  
  end end end
  
  renderAllLayers(grid);
  
end

function castle.postopened(post)
  
  --FromPost = true;
  
  state.grid.voxels = post.data.voxels;
  --state.options = post.data.options;
  
  for k,v in pairs(post.data.options) do
    state.options[k] = v;
  end
  
  state.cameraAngles = vec2(post.data.cameraAngles[1], post.data.cameraAngles[2]);
  state.cameraZoom = post.data.cameraZoom;
  
  
    print("Loaded Camera Settings", state.cameraZoom, state.cameraAngles:to_string());
  
  state.grid.width = post.data.width or 16;
  state.grid.height = post.data.height or 16;
  state.grid.depth = post.data.depth or 16;
  
  local ct = post.data.camTarget;
  
  if (ct) then
    state.camTarget = vec3(ct[1], ct[2], ct[3]);
    print("Loaded Camera Target", state.camTarget:to_string());
  end
  
  updateCamera3D(0,0);
  
  renderAllLayers(state.grid);
  
end

function postGrid(grid)


  network.async(function()
      castle.post.create {
          message = 'Voxelize This',
          media = 'capture',
          data = {
              voxels = grid.voxels,
              width = grid.width,
              height = grid.height,
              depth = grid.depth,
              options = state.options,
              cameraAngles = {state.cameraAngles.x, state.cameraAngles.y},
              cameraZoom = state.cameraZoom,
              camTarget = {state.camTarget.x, state.camTarget.y, state.camTarget.z}
          }
      }
  end)

end

local renderSectionToggle = true;
local editSectionToggle = true;
local postSectionToggle = true;
local sceneSectionToggle = false;
local cameraSectionToggle = false;

local uiGridResolution = 16;

function castle.uiupdate()

    local clear = false;
    local post = false;
    local undo = false;
    
    --postSectionToggle = ui.section('Post', {open = postSectionToggle}, function()
      
      post = ui.button("Post to Castle!");
    
    --end);

    
    sceneSectionToggle = ui.section('Scene', {open = sceneSectionToggle}, function()
      
      uiGridResolution = ui.slider('Grid Resolution', uiGridResolution, 16, 64);
      
      clear = ui.button("Reset Scene");

    end);
    
    editSectionToggle = ui.section('Editing', {open = editSectionToggle}, function()
      state.color[1] = ui.slider('r', state.color[1] * 255, 0, 255) / 255;
      state.color[2] = ui.slider('g', state.color[2] * 255, 0, 255) / 255;
      state.color[3] = ui.slider('b', state.color[3] * 255, 0, 255) / 255;
      
      state.tool = ui.radioButtonGroup('Tool', state.tool, {'add', 'remove', 'pick color', 'fill'});
      
      undo = ui.button("Undo ("..List.length(state.snapshots)..")");
      
    end)
    
        
    renderSectionToggle = ui.section('Rendering', {open = renderSectionToggle}, function() 
      
      state.options.showGrid = ui.checkbox("Show Grid", state.options.showGrid, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      });
      
      state.options.quality = ui.numberInput("Render Quality (1-5)", state.options.quality, {
        min = 1, 
        max = 5,
        onChange = function(val)
          state.renderQuality = val;
          state.forceQuality = true;
          state.dirtyVoxels = true;
        end
      });
      
      --[[
      state.options.canvasSize = ui.numberInput("Canvas Size(1-3)", state.options.canvasSize, {
        min = 1, 
        max = 3,
        onChange = function(val)
           state.options.canvasSize = val;
           adjustViewport(val);
        end
      });
      ]]
      
      state.options.reflectionScale = ui.slider("Reflection", state.options.reflectionScale * 100, 0, 100, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      }) / 100.0;
      
       state.options.envScale = ui.slider("Environment Intensity", state.options.envScale * 100, 0, 100, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      }) / 100.0;
      
      state.options.sunScale = ui.slider("Sun Instensity", state.options.sunScale * 100, 0, 100, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      }) / 100.0;
      
      state.options.sunAngle = ui.slider("Sun Angle", state.options.sunAngle * 360, 0, 360, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      }) / 360;
      
      state.options.sunIncline = ui.slider("Sun Incline", state.options.sunIncline * 90, 0, 90, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      }) / 90;
      
    end)
    
    cameraSectionToggle = ui.section('Camera', {open = cameraSectionToggle}, function()
      
      state.cameraMode = ui.radioButtonGroup('Camera Mode', state.cameraMode, {'orbit', 'first person'}, {
        
        onChange = function(val) 
          
          state.cameraMode = val;
          
          if (val == 'first person') then
            
            state.headMatrix[13] = state.grid.width * 0.5;
            state.headMatrix[14] = state.grid.height * 0.5;
            state.headMatrix[15] = -state.grid.depth;

          else --orbit
                
            --[[
            state.camTarget = vec3(state.grid.width * 0.5, state.grid.height * 0.5, state.grid.height * 0.5);
            ]]
            
          end
                      
          state.cameraAngles.x = 0.0;
          state.cameraAngles.y = 0.0;
          
          updateCamera3D(0,0);
          state.dirtyVoxels = true;
        
        end
      
      });      
    end)

    if (post) then
      postGrid(state.grid);
    end
    
    if (clear) then
    
      state.grid.width = uiGridResolution;
      state.grid.height = uiGridResolution;
      state.grid.depth = uiGridResolution;
    
      clearGrid(state.grid);
    end
    
    if (undo) then
      loadSnapshot();
    end
    
end

function client.visible(visible)
  state.dirtyVoxels = visible;
end

print("Ready To Load");

function client.load()
  
  print("Load Start");

  assets.img = {
    rotate = love.graphics.newImage("img/rotate-camera.png")
  }
  
  print("Loaded imgs")
 
 assets.renderShader, assets.queryShader = makeShaders();

 print("Created Shaders");
 
  state.grid = {
    layers = {},
    depth = 16,
    width = 16,
    height = 16
  }
  
  state.cameraAngles = vec2(0.0, 0.0);
  state.cameraZoom = 30;
  state.color = {1,1,1,1}
  state.tool = 'add';
  
  
  state.options = {
    showGrid = false,
    --envLight = true,
    reflectionScale = 0.0,
    sunScale = 0.3,
    envScale = 0.3,
    quality = 2,
    canvasSize = 2,
    sunAngle = 0.08,
    sunIncline = 0.55,
    skyColor = {0.4, 0.7, 1.0, 1.0},
    sunColor = {0.95, 0.9, 0.8}
  }
  
  state.cameraMode = 'orbit';
  state.renderQuality = 3;
  
  state.snapshots = List.new(1);
  
  local offsetX = 200;
  
  state.ui = {
  
    viewport = {
      x = offsetX,
      y = 24,
      w = 380,
      h = 380
    },
    
    cambutton = {
      y = 24 + 5,
      x = offsetX + 5,
      w = 32,
      h = 32
    }
  
  }
  
  assets.queryCanvas = love.graphics.newCanvas(1, 1, {dpiscale=1});

  assets.renderCanvas = love.graphics.newCanvas(state.ui.viewport.w, state.ui.viewport.h);

  print("Created Canvases");
  
  state.headMatrix = mat4();
  state.headMatrix:translate(state.headMatrix, vec3(8,8,-10));
  
  --print(state.headMatrix:to_string());
  
  clearGrid(state.grid);
  
  state.color = {1.0, 0.0, 0.85, 1.0};
  
  updateCamera3D(50,50);
  
end