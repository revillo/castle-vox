--castle://localhost:4000/vox.castle

local cpml = require("lib/cpml")
local mat4 = cpml.mat4;
local vec3 = cpml.vec3;

function headLook(out, eye, look_at, up)
	local z_axis = (look_at - eye):normalize()
	local x_axis = z_axis:cross(up):normalize()--up:cross(z_axis):normalize() * vec3(-1, -1, -1);
   
  
	local y_axis = x_axis:cross(z_axis):normalize()
  
	out[1] = x_axis.x
	out[2] = y_axis.x
	out[3] = z_axis.x
	out[4] = 0
	out[5] = x_axis.y
	out[6] = y_axis.y
	out[7] = z_axis.y
	out[8] = 0
	out[9] = x_axis.z
	out[10] = y_axis.z
	out[11] = z_axis.z
	out[12] = 0
	out[13] = eye.x
	out[14] = eye.y
	out[15] = eye.z
	out[16] = 1

  return out
end

local client = love;


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

end

function randomizeGrid(grid) 
  
  local w, h = grid.width, grid.height;
  
  grid.gpu = love.graphics.newCanvas(grid.width, grid.height * grid.depth);
  grid.gpu:setWrap("clampzero", "clampzero");
  grid.gpu:setFilter("nearest", "nearest");
  
  
  for z = 1,grid.depth do
    
    grid.layers[z] = {
      gpu = love.graphics.newCanvas(grid.width, grid.height),
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
      
      if y == 16 then
        layer[x][y] = {0.3, 0.2, 0.0, 1.0}
      elseif dist < 3 then
        layer[x][y] = {0.3, 0.6, 0.2, 1.0}
      end
      
    end
    end
    
    renderLayer(grid, z);

  end
end

local state = {
  
}

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

function makeShader()

  local vert = [[
    varying vec3 pos;
    varying float shade;
    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        vec4 vp = vertex_position;
        pos = vertex_position.xyz;
        return transform_projection * vp;
    }
  ]];
  
  local frag = [[
    varying vec3 pos; 
    varying float shade;
    uniform mat4 headMatrix;
    extern Image grid_1;
    
    vec4 sampleGrid(vec3 pos)
    {
      float z = pos.z;
      
      if (z < 0.0 || z >= 16.0 || pos.x < 0.0 || pos.x >= 16.0 || pos.y < 0.0 || pos.y >= 16.0) {
        return vec4(0.0);
      }      
      
      float layer = floor(z);
      
      vec2 uv;
      uv.x = (floor(pos.x) + 0.5) / 16.0;
      uv.y = (floor(pos.y + layer * 16.0) + 0.5) / 256.0;   
      
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
      
       //return (pos + dir * (t));
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
      
      //return vec4(dir * 0.2 + vec3(0.1), 1.0);
      //skycolor
      return vec4(vec3(0.4, 0.7, 1.0) * (-dir.y * 0.3 + 0.7), 1.0);
    }
    
       
    #define PI 3.14159
    void traceAO(in vec3 origin, in vec3 normal, inout vec3 outColor, float quality) {
      
      vec3 randvec = normalize(vec3(normal.y, -normal.z, normal.x));
      vec3 tangent = normalize(randvec - dot(randvec, normal) * normal);
      mat3 aligned_mat = mat3(tangent, normalize(cross(normal, tangent)), normal);  
      
      vec3 color = vec3(0.0);
      
      //Randomly rotate the alignment matrix to jitter samples
      //aligned_mat = AAm3(vec4(normal, randAngle(uv))) * aligned_mat;

       float step = 0.8 / (quality * 32.0 + 16);
        
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
           
          vec4 sample = trace(origin, direction, op, on, hit, 5);
          
          //float weight = dot(direction, normal) * (1.0 - float(hit));
          float weight = dot(direction, normal);
          
          vec3 envLight = vec3(-direction.y * 0.1 + 0.9);
          
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
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
        
        vec3 dir = vec3(texture_coords * 2.0 - vec2(1.0), 1.0);
        dir.x *= -1.0;
        
        dir.xy *= 0.5;
        
        dir = normalize(dir);
        
        //vec3 origin = vec3(8.0, 8.0, -10.0) + offset;
        dir = normalize((headMatrix * vec4(dir, 0.0)).xyz);
        
        vec3 origin = headMatrix[3].xyz;
        
        vec3 normal;
        vec3 pos;
        bool hit;
        color = trace(origin, dir, pos, normal, hit, 128);
        
        float hitDist = length(pos - origin);
        
        if (! hit) {
          return color;
        }
        
       float shade = 1.0;
              
       //Directional Light
        vec3 lightDir = normalize(vec3(1.0, -3.0, -2.0));
        shade = max(0.0, dot(lightDir, normal));

        vec3 p2, n2;
        trace(pos + lightDir * 0.01, lightDir, p2, n2, hit, 64);
        
        if (hit) {
          shade = 0.0;
        }
       
       //Ambient Occlusion
       vec3 aoColor = vec3(0.0);
       float aoQuality = clamp(1.0 - (hitDist / 20.0), 0.0, 1.0);
       traceAO(pos + normal * 0.01, normal, aoColor, aoQuality); 
       //color =  clr * vec4(aoColor * (shade * 0.2 + 0.8), 1.0);
               
        //return vec4(normal * 0.5 + vec3(0.5), 1.0);
        //return clr * shade;
        
        //Specular
        vec3 bounceDir = reflect(dir, normal);
        vec4 bounceSample = trace(pos + bounceDir * 0.01, bounceDir, p2, n2, hit, 64);
        float spec = pow(max(0.0, dot(bounceDir, lightDir)), 10.0);
        
        if (shade < 0.01) {
          spec = 0.0;
        }
        
        //Apply Specular
        color.rgb += bounceSample.rgb * 0.1 + spec * vec3(1.0, 1.0, 0.9);

        //Apply Shading
        color.rgb *= (aoColor * (shade * 0.3 + 0.7));
        
        return color;
    }
  ]];
  
  return love.graphics.newShader(vert, frag)
  
end


local assets = {
  
  quadMesh = makeQuad(),
  rayShader = makeShader()

}

local tempHeadMat = mat4();
function draw3D(grid)
  
  love.graphics.setColor({1,1,1,1});
  love.graphics.setShader(assets.rayShader);
  
  mat4.transpose(tempHeadMat, state.headMatrix);

  assets.rayShader:send("headMatrix", tempHeadMat);
  
  assets.rayShader:send("grid_1", grid.gpu);
  
  love.graphics.draw(assets.quadMesh, 412, 24, 0, 380, 380);
  love.graphics.setShader();
  
end

function drawGrid(grid)
  
  love.graphics.setColor(1,1,1,1);
  
  for z = 0, grid.depth-1 do
    
    local x = z % 4;
    local y = math.floor(z / 4);
    
    love.graphics.draw(grid.layers[z + 1].gpu, 24 + x * 100, 24 + y * 100, 0, 4, 4);
    
  end
  
 --love.graphics.draw(grid.gpu, 0, 0, 0, 1, 1);
  
  draw3D(grid);

end

function client.draw()
  
  state.offset3D[3] = math.sin(love.timer.getTime()) * 10.0 + 10.0;
  state.offset3D[2] = math.sin(love.timer.getTime() * 2) * 2;
  
  drawGrid(state.grid);

end


function client.mousepressed(x, y)
  
  
  
end

function client.update(dt)
  
    local t = love.timer.getTime();
    
   --local eye = vec3(math.sin(t) * 20, 8.0, math.cos(t) * 20);
   local radius = 28.0;
   
   local target = vec3(8.0, 8.0, 8.0);

    local eye = vec3(math.sin(t) * radius, 0.0,  math.cos(t) * radius);
    
    eye = eye + target;
    local up = vec3(0.0, 1.0, 0.0);
    
    headLook(state.headMatrix, eye, target, up);
   
--   state.headMatrix:scale(state.headMatrix, vec3(1,1,-1));
--   state.headMatrix:translate(state.headMatrix, eye);
 
 
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

function client.load()
  
  state.grid = {
    layers = {},
    depth = 16,
    width = 16,
    height = 16
  }
  
  state.offset3D = {
    0, 0, 0
  }
  
  state.headMatrix = mat4();
  state.headMatrix:translate(state.headMatrix, vec3(8,8,-10));
  
  print(state.headMatrix:to_string());
  
  randomizeGrid(state.grid);

end 