--castle://localhost:4000/main.lua

local client = love;


function renderLayer(grid, z)

  local layer = grid.layers[z];
  love.graphics.setCanvas(layer.gpu);
  local w, h = grid.width, grid.height;
    
  for x = 1,w do
  for y = 1,h do
    
    love.graphics.setColor(layer.cpu[x][y]);
    love.graphics.rectangle("fill", x-1, y-1, 1, 1);
  end end
    
  love.graphics.setCanvas()

end

function randomizeGrid(grid) 
  
  local w, h = grid.width, grid.height;
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
    
      if (math.random() < 0.1 and y < 14) then
        layer[x][y] = {
          math.random(),math.random(),math.random(),1
        }
      else
        layer[x][y] = {
         0,0,0,0
        }
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
    extern vec2 scale;
    varying vec3 pos;
    varying float shade;
    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        vec4 vp = vertex_position;
        vp.xy *= scale;
        pos = vertex_position.xyz;
        return transform_projection * vp;
    }
  ]];
  
  local imgs = "";
  
  for i = 1,16 do
    imgs = imgs.."extern Image grid_"..tostring(i)..";\n";
  end
  
  --Lawdy forgive me
  local frag = imgs..[[
    varying vec3 pos; 
    varying float shade;
    uniform vec3 offset;
    
    vec4 sampleGrid(float z, vec2 uv)
    {
    //  z += 0.01;

      if (uv.y >= 1.0) {
        return vec4(1.0, 1.0, 1.0, 2.0);
      }
      
      if (z < 0.0 || z > 16.0 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0 || uv.y > 1.0) {
        return vec4(0.0);
      }
     
      
      if (z < 8.0) {
          
          if (z < 4.0) {
            
            if (z < 2.0)  {
              
              if (z < 1.0) {
                return Texel(grid_1, uv);
              } else {
                return Texel(grid_2, uv);
              }
              
            } else {
            
              if (z < 3.0) {
                return Texel(grid_3, uv);
              } else {
                return Texel(grid_4, uv);
              }
            
            }
            
          } else {
            
             if (z < 6.0)  {
              
              if (z < 5.0) {
                return Texel(grid_5, uv);
              } else {
                return Texel(grid_6, uv);
              }
              
            } else {
            
              if (z < 7.0) {
                return Texel(grid_7, uv);
              } else {
                return Texel(grid_8, uv);
              }
            
            }
            
          }

       
      } else {
      
        if (z < 12.0) {
            
            if (z < 2.0)  {
              
              if (z < 9.0) {
                return Texel(grid_9, uv);
              } else {
                return Texel(grid_10, uv);
              }
              
            } else {
            
              if (z < 11.0) {
                return Texel(grid_11, uv);
              } else {
                return Texel(grid_12, uv);
              }
            
            }
            
          } else {
            
             if (z < 14.0)  {
              
              if (z < 13.0) {
                return Texel(grid_13, uv);
              } else {
                return Texel(grid_14, uv);
              }
              
            } else {
            
              if (z < 15.0) {
                return Texel(grid_15, uv);
              } else {
                return Texel(grid_16, uv);
              }
            
            }
            
          }
      
      }
    
    }
    
    float dc(float v, float d) {
      if (d > 0.0) {
        return (ceil(v) - v) / d;
      } else if (d < 0.0) {
        return -fract(v) / d;
      } else {
        return 10000.0;
      }
    }
    
    //Advance ray into next unit cell
    vec3 advance(vec3 pos, vec3 dir) {
      
       vec3 ds = vec3(dc(pos.x, dir.x), dc(pos.y, dir.y), dc(pos.z, dir.z));
       float t = min(ds.z, min(ds.x, ds.y));
       return pos + dir * (t + 0.001); 
       //return pos + dir/10.0;
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
    
    vec4 trace2(vec3 origin, vec3 dir, out vec3 pos, out vec3 normal, out bool hit, int tMax) {
      
      pos = origin;
      
      for (int i = 0; i < tMax; i++) {
        pos = advance(pos, dir);
         
        vec4 sample = sampleGrid(pos.z, pos.xy / 16.0);  

        if (sample.a > 1.1) {
          normal = vec3(0.0, -1.0, 0.0);
          hit = true;
          return sample;
        } else if (sample.a > 0.1) {
          normal = getNormal(pos, dir);
          hit = true;
          return sample;
        }
          
      }
      
      hit = false;
      
      return vec4(dir * 0.2 + vec3(0.1), 1.0);
    }
    
    vec4 trace(vec3 origin, vec3 dir) {
      
       vec3 pos = origin;
       vec3 step = dir / 10.0;

       
        for (int i = 0; i < 320; i++) {

          pos += step;
          vec4 sample = sampleGrid(pos.z, pos.xy / 16.0);  

          if (sample.a > 0.1) {
            return sample;
          }
          
        }
        
      return vec4(dir * 0.2 + vec3(0.1), 1.0);
    
    }
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
        
        vec3 dir = vec3(texture_coords * 2.0 - vec2(1.0), 1.0);

        dir.xy *= 1.0;
        
        dir = normalize(dir);
        
        vec3 origin = vec3(8.0, 8.0, -10.0) + offset;
        vec3 normal;
        vec3 pos;
        bool hit;
        vec4 clr = trace2(origin, dir, pos, normal, hit, 64);
        
        if (! hit) {
          return clr;
        }
        
        //vec3 lightDir = normalize(vec3(1.0, 3.0, 2.0));
        vec3 lightDir = normalize(vec3(1.0, -3.0, -2.0));
        float shade = max(0.0, dot(lightDir, normal));
        
        vec3 p2, n2;
        trace2(pos + lightDir * 0.01, lightDir, p2, n2, hit, 64);
        
        if (hit) {
          shade = min(shade, 0.4);
        }
        
        return clr * shade;
        
    }
  ]];
  
  return love.graphics.newShader(vert, frag)
  
end


local assets = {
  
  quadMesh = makeQuad(),
  rayShader = makeShader()

}

function draw3D(grid)
  
  love.graphics.setColor({1,1,1,1});
  love.graphics.setShader(assets.rayShader);
  assets.rayShader:send("scale", {300, 300});
  assets.rayShader:send("offset", state.offset3D);
  
  for z = 1, 16 do
    assets.rayShader:send("grid_"..z, grid.layers[z].gpu);
  end
  
  love.graphics.draw(assets.quadMesh, 100, 100);
  love.graphics.setShader();
  
end

function drawGrid(grid)
  
  love.graphics.setColor(1,1,1,1);
  
  for z = 1, grid.depth do
    
    love.graphics.draw(grid.layers[z].gpu, z * 30, 10);
    
  end
  
  draw3D(grid);

end

function client.draw()
  
  state.offset3D[3] = math.sin(love.timer.getTime()) * 10.0 + 10.0;
  state.offset3D[2] = math.sin(love.timer.getTime() * 2) * 2;
  
    drawGrid(state.grid);

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
  
  randomizeGrid(state.grid);

end