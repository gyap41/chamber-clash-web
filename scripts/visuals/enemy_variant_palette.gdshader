shader_type canvas_item;
uniform bool iron = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec3 rgb = source.rgb;
 float hi = max(rgb.r,max(rgb.g,rgb.b));
 float lo = min(rgb.r,min(rgb.g,rgb.b));
 // Primitive shadows, health bars and hit flashes keep their own colors.
 if (TEXTURE_PIXEL_SIZE.x < 0.01 && hi-lo > 0.035 && hi > 0.12) {
  float value = dot(rgb,vec3(0.299,0.587,0.114));
  if (iron) {
   vec3 metal = value < 0.55 ? vec3(0.67,0.83,1.0) : vec3(0.86,0.94,1.0);
   rgb = metal * min(value*1.16,1.0);
  } else if (rgb.g > rgb.b*1.18 && rgb.g > rgb.r*0.72) {
   rgb = vec3(0.92,0.38,0.20)*min(value*1.40,1.0);
  }
 }
 COLOR = tint * vec4(rgb,source.a);
}
