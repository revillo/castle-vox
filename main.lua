--castle://localhost:4000/vox.castle

local cpml = require("lib/cpml")
local mat4 = cpml.mat4;
local vec3 = cpml.vec3;
local vec2 = cpml.vec2;
local ui = castle.ui;

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

function renderLayer(grid, z)

  local layer = grid.layers[z];
  love.graphics.setBlendMode("replace", "premultiplied");  

  --Per Layer
  love.graphics.setCanvas(layer.gpu);
  local w, h = grid.width, grid.height;
  for x = 1,w do
  for y = 1,h do
    
    love.graphics.setColor(layer.cpu[x][y]);
    love.graphics.rectangle("fill", x-1, y-1, 1, 1);
  end end
    
  love.graphics.setCanvas()
  
  
  --Tiled
  love.graphics.setCanvas(grid.gpu);
  
  --[[
  for x = 1,w do
  for y = 1,h do
    
    love.graphics.setColor(layer.cpu[x][y]);
    love.graphics.rectangle("fill", x-1.1, (z-1) * grid.height + y-1.1, 1.1, 1.1);
   end end
  ]]
  
  love.graphics.setColor(1,1,1,1);
  love.graphics.draw(layer.gpu, 0, (z-1) * 16);
  love.graphics.setCanvas();
  love.graphics.setBlendMode("alpha");
  
  state.dirtyVoxels = true;
  
end


function clearGrid(grid) 
  
  local w, h = grid.width, grid.height;
  
  grid.gpu = love.graphics.newCanvas(grid.width, grid.height * grid.depth, {dpiscale=1});
  grid.gpu:setWrap("clampzero", "clampzero");
  grid.gpu:setFilter("nearest", "nearest");
  
  
  for z = 1,grid.depth do
    
    grid.layers[z] = {
      gpu = love.graphics.newCanvas(grid.width, grid.height, {dpiscale=1}),
      cpu = {}
    };
    
    grid.layers[z].gpu:setWrap("clampzero", "clampzero");
    grid.layers[z].gpu:setFilter("nearest", "nearest");
    
    local size = grid.width * grid.height;
    local layer = grid.layers[z].cpu;
    
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
      
      if y == 16 then
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
      
      pos = origin;
      
      for (int i = 0; i < tMax; i++) {
        pos = advance(pos, dir, normal);
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
    uniform bool showGrid;
    uniform int sampling;
    uniform vec2 viewportSize;
    
    vec4 getSkyColor(vec3 direction) 
    {
      
      float t = dot(-direction, lightDir) * 0.3 + 0.7;
      return vec4(mix(vec3(0.4, 0.7, 1.0), vec3(0.95, 0.9, 0.8),1.0-t), 1.0);
    }
       
    #define PI 3.14159
    void traceAO(in vec3 origin, in vec3 normal, inout vec3 outColor, float quality) {
      
      vec3 randvec = normalize(vec3(normal.y, -normal.z, normal.x));
      vec3 tangent = normalize(randvec - dot(randvec, normal) * normal);
      mat3 aligned_mat = mat3(tangent, normalize(cross(normal, tangent)), normal);  
      
      vec3 color = vec3(0.0);
      
      //Randomly rotate the alignment matrix to jitter samples
      //aligned_mat = AAm3(vec4(normal, randAngle(uv))) * aligned_mat;

      float step = 0.8 / (quality * 10.0 + 10.0);
        
        float weightSum = 0.0;
        
        //Hemisphere integral
        for (float aa = 0.1; aa <= 0.9; aa += step) {
          for (float bb = 0.1; bb <= 0.9; bb += step) {

           vec3 ray = vec3(
              cos(aa * PI * 2) * cos(bb * PI), 
              sin(aa * PI * 2) * cos(bb * PI),
              sin(bb * PI)
            );
            
           vec3 direction = aligned_mat * ray;
           
           vec3 op, on;
           bool hit;
           
          vec4 sample = trace(origin, direction, op, on, hit, 3);
          
          //float weight = dot(direction, normal) * (1.0 - float(hit));
          float weight = dot(direction, normal);
          
          vec3 envLight = getSkyColor(direction).rgb;//vec3(-direction.y * 0.1 + 0.9);
          envLight = mix(envLight, vec3(1.0, 1.0, 1.0), 0.5);
          
          //Ambient Light
          color += envLight * weight  * (1.0 - float(hit));
          //Bounce Light
          color += sample.rgb * weight * float(hit) * 0.75;

          weightSum += weight;

          }      
        }
        
        color /= weightSum; 
        outColor += color;
    }
    
    float edgeLength(vec3 pos) {
      vec3 d = abs(pos - (floor(pos) + vec3(0.5)));
      return max(d.y + d.z, max(d.x + d.y, d.x + d.z));
    }
    
    vec4 raycast(vec2 texture_coords, out bool isEdge)
    {
      vec3 origin, dir;
        getHeadRay(texture_coords, origin, dir);
        
        vec3 normal;
        vec3 pos;
        bool hit;
        vec4 color = trace(origin, dir, pos, normal, hit, 128);
        
        float hitDist = length(pos - origin);
        isEdge = false;
        
        if (! hit) {
          return getSkyColor(dir);
        }
        
       float shade = 1.0;
              
        //Directional Light
        //vec3 lightDir = normalize(vec3(1.0, -3.0, -2.0));
        shade = max(0.0, dot(lightDir, normal));

        vec3 p2, n2;
        trace(pos + lightDir * 0.01, lightDir, p2, n2, hit, 64);
        
        if (hit) {
          shade = 0.0;
        }
        
       isEdge = edgeLength(pos) > 0.97;
        
       //Ambient Occlusion
       vec3 aoColor = vec3(0.0);
       float aoQuality = clamp(1.0 - (hitDist / 20.0), 0.0, 1.0);
       traceAO(pos + normal * 0.001, normal, aoColor, aoQuality); 
 
        //Specular
        vec3 bounceDir = reflect(dir, normal);
        vec4 bounceSample = trace(pos + bounceDir * 0.01, bounceDir, p2, n2, hit, 32);
        float spec = pow(max(0.0, dot(bounceDir, lightDir)), 10.0);
        
        if (shade < 0.01) {
          spec = 0.0;
        }
        
        //Apply Specular
        color.rgb += bounceSample.rgb * bounceSample.a * 0.05 + spec * vec3(1.0, 1.0, 0.9);

        //Apply Shading
        color.rgb *= (aoColor * (shade * 0.2 + 0.8));
        color = clamp(color, vec4(0.0), vec4(1.0));

        if (isEdge && showGrid) {
          color = clamp(color, vec4(0.0), vec4(1.0));
          color.rgb = vec3(1.0) - color.rgb;
          color.rgb = mix(color.rgb, vec3(1.0), 0.2);
        }
        
        return color;
    }
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
        bool isEdge = false;
        
        float aa = 0.5/viewportSize.x;
        
        vec4 clr = raycast(texture_coords, isEdge);
        
        if (sampling == 2) {
          clr += raycast(texture_coords + vec2(aa), isEdge);
          clr *= 0.5;
        } else if (sampling == 4) {
          clr += raycast(texture_coords + vec2(aa, 0), isEdge);
          clr += raycast(texture_coords + vec2(aa, aa), isEdge);
          clr += raycast(texture_coords + vec2(0, aa), isEdge);
          clr *= 0.25;
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

assets.renderShader, assets.queryShader = makeShaders();


local tempHeadMat = mat4();
local tempLightDir = vec3();

local SAMPLING_QUALITY = {1, 2, 4};

function renderVoxels(grid)

  if (not state.dirtyVoxels) then
    return
  end

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
  assets.renderShader:send("sampling", SAMPLING_QUALITY[state.options.quality]);
  assets.renderShader:send("viewportSize", {state.ui.viewport.w * pixelScale, state.ui.viewport.h * pixelScale});
  
  tempLightDir = vec3(1.0, -3.0, -2.0):normalize();
  
  assets.renderShader:send("lightDir", {tempLightDir.x, tempLightDir.y, tempLightDir.z});
  
  local vp = state.ui.viewport;
  love.graphics.draw(assets.quadMesh, 0, 0, 0, vp.w, vp.h);

  love.graphics.setShader();
  love.graphics.setCanvas();
  
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


local queryCanvas = love.graphics.newCanvas(1, 1, {dpiscale=1});

function drawGrid2D(grid)
  
  love.graphics.setColor(1,1,1,1);
  
  for z = 0, grid.depth-1 do
    
    local x = z % 4;
    local y = math.floor(z / 4);
    
    love.graphics.draw(grid.layers[z + 1].gpu, 24 + x * 100, 24 + y * 100, 0, 4, 4);
    
  end
  
  --love.graphics.draw(queryCanvas, 0, 0, 0, 10, 10);
  
 --love.graphics.draw(grid.gpu, 0, 0, 0, 1, 1);
 
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
  print("here", love.window.getDPIScale());
  
end

function client.draw()
  
  --drawGrid2D(state.grid);
  drawGrid3D(state.grid);
  drawUI();
  
end

function client.wheelmoved(x, y)
  
  state.cameraZoom = cpml.utils.clamp(state.cameraZoom - y, 5.0, 60.0);
  updateCamera3D(0,0);
  state.dirtyVoxels = true;
  
end

function contains(x, y, box)
  return x >= box.x and y >= box.y and x < box.x + box.w and y < box.y + box.h; 
end

function controlCamera(toggle)
  love.mouse.setRelativeMode(toggle);
  state.ui.cameraMode = toggle;
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
    state.grid.layers[z].cpu[x][y] = {r, g, b, a};
    
  end end end
  
  renderAllLayers(state.grid);

end

function updatePaint2D()
  local mx, my = love.mouse.getPosition();
  
  
  local ix, iy = (mx - 24) / 100, (my - 24)/100;
    
    if (ix >= 4 or iy >= 4) then
      return;
    end
    
    local z = math.floor(iy) * 4 + math.floor(ix) + 1;
    
    
    local px, py = (ix - math.floor(ix)) * 25, (iy - math.floor(iy)) * 25;
    px, py = math.floor(px) + 1, math.floor(py) + 1;
    
    if (px > 16 or py > 16) then
      return;
    end
    
  if (love.mouse.isDown(1)) then
    
    state.grid.layers[z].cpu[px][py] = {
      1, 1, 1, 1
    }
    
    renderLayer(state.grid, z);
    
  elseif (love.mouse.isDown(2)) then
  
    state.grid.layers[z].cpu[px][py] = {
      0, 0, 0, 0
    }
    
    renderLayer(state.grid, z);
    
  end
    
end

function removeVoxel(grid, x, y, z)
  
  if (not grid.layers[z]) or (not grid.layers[z].cpu[x]) or (not grid.layers[z].cpu[x][y]) then
    return ;
  end
  
  grid.layers[z].cpu[x][y] = {
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
  
  if (not grid.layers[z]) or (not grid.layers[z].cpu[x]) or (not grid.layers[z].cpu[x][y]) then
    return
  end
  
  local vc = grid.layers[z].cpu[x][y];
  
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
  
  if (not grid.layers[z]) or (not grid.layers[z].cpu[x]) or (not grid.layers[z].cpu[x][y]) then
    return ;
  end

  local c = state.color;
  
  grid.layers[z].cpu[x][y] = {
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
  
  love.graphics.setCanvas(queryCanvas);
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

  local r,g,b,a = queryCanvas:newImageData(1, 1, 0, 0, 1, 1):getPixel(0,0);
  
  if (a < 0.1) then return end;

  local x, y, z = math.floor(r * grid.width) + 1, math.floor(g * grid.height) + 1, math.floor(b * grid.depth) + 1;
  
  if (tool == "add") then
    addVoxel(grid, x, y, z);
  elseif (tool == "remove") then
    removeVoxel(grid, x, y, z);
  elseif (tool == "pick color") then
    local pc = grid.layers[z].cpu[x][y];
    state.color = {pc[1], pc[2], pc[3], pc[4]};
  elseif (tool == "fill") then
    local pc = grid.layers[z].cpu[x][y];
    local vc = {};
    ColorUtil.copy(vc, pc);
    if(ColorUtil.equals(vc, state.color)) then return end;
    fillVoxel(grid, x, y, z, vc);
    renderAllLayers(grid);
  end
  
end

local tempCameraPosition = vec3();
function updateCamera3D(dx, dy)
  
  if (dx ~= 0.0 or dy ~= 0.0) then
    state.dirtyVoxels = true;
  end
  
  local cameraAngles = state.cameraAngles;
  
  local sensitivity = 0.01;
  cameraAngles.x = cameraAngles.x - dx * sensitivity;
  cameraAngles.y = cameraAngles.y - dy * sensitivity;
  cameraAngles.y = cpml.utils.clamp(cameraAngles.y, -math.pi * 0.45, math.pi * 0.45);

  tempCameraPosition.x = math.sin(cameraAngles.x) * math.cos(cameraAngles.y);
  tempCameraPosition.z = math.cos(cameraAngles.x) * math.cos(cameraAngles.y);
  tempCameraPosition.y = math.sin(cameraAngles.y);
  
  
  local target = vec3(8.0, 9.0, 8.0);

  tempCameraPosition = tempCameraPosition:scale(state.cameraZoom) + target;
  local up = vec3(0.0, 1.0, 0.0);

  headLook(state.headMatrix, tempCameraPosition, target, up);
  
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

function client.update(dt)
  
  if (dpiSave ~= love.window.getDPIScale()) then
    dpiSave = love.window.getDPIScale();
    w,h = love.graphics.getDimensions();
    handleResize(w, h);
  end
  
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

local renderSectionToggle = true;
local editSectionToggle = true;

function castle.uiupdate()

    local clear = false;
    
    renderSectionToggle = ui.section('Rendering', {open = renderSectionToggle}, function() 
      
      state.options.showGrid = ui.checkbox("Show Grid", state.options.showGrid, {
        onChange = function()
          state.dirtyVoxels = true;
        end
      });
      
      state.options.quality = ui.numberInput("Quality", state.options.quality, {
        min = 1, 
        max = 3,
        onChange = function()
          state.dirtyVoxels = true;
        end
      });
     
    end)
    
    editSectionToggle = ui.section('Editing', {open = editSectionToggle}, function()
      state.color[1] = ui.slider('r', state.color[1] * 255, 0, 255) / 255;
      state.color[2] = ui.slider('g', state.color[2] * 255, 0, 255) / 255;
      state.color[3] = ui.slider('b', state.color[3] * 255, 0, 255) / 255;
      
      state.tool = ui.radioButtonGroup('Tool', state.tool, {'add', 'remove', 'pick color', 'fill'});
      
      clear = ui.button("Clear All");
    end)
    
    if (clear) then
      clearGrid(state.grid);
    end
    
end

function client.load()
  
  assets.img = {
    
    rotate = love.graphics.newImage("img/rotate-camera.png")
  
  }
  

  
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
    quality = 2,
  }
  
  
  state.ui = {
  
    viewport = {
      y = 24,
      x = 50,
      w = 380,
      h = 380
    },
    
    cambutton = {
      y = 24,
      x = 60,
      w = 32,
      h = 32
    }
  
  }
  
  assets.renderCanvas = love.graphics.newCanvas(state.ui.viewport.w, state.ui.viewport.h);

  
  state.headMatrix = mat4();
  state.headMatrix:translate(state.headMatrix, vec3(8,8,-10));
  
  --print(state.headMatrix:to_string());
  
  clearGrid(state.grid);
  updateCamera3D(50,50);

end