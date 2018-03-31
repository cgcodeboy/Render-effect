// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/test"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"


			struct v2f{
                float4 position : SV_POSITION;
            };

            v2f vert(float4 v:POSITION) : SV_POSITION {
                v2f o;
                o.position = UnityObjectToClipPos (v);
                return o;
            }

			float3x3 fromEuler(float3 ang){
				float2 a1 = float2(sin(ang.x),cos(ang.x));
				float2 a2 = float2(sin(ang.y),cos(ang.y));
				float2 a3 = float2(sin(ang.z),cos(ang.z));
				float3x3 m;
				m[0] = float3(a1.y*a3.y+a1.x*a2.x*a3.x,a1.y*a2.x*a3.x+a3.y*a1.x,-a2.y*a3.x);
				m[1] = float3(-a2.y*a1.x,a1.y*a2.y,a2.x);
				m[2] = float3(a3.y*a1.x*a2.x+a1.y*a3.x,a1.x*a3.x-a1.y*a3.y*a2.x,a2.y*a3.y);
				return m;
			}

			float mix(float x,float y,float a){
				return x * (1 - a) + y * a;
			}

			float2 mixVec2(float2 aa, float2 bb,float2 cc){
				return float2(mix(aa.x,bb.x,cc.x),mix(aa.y,bb.y,cc.y));
			}

			float3 mixVec3(float3 aa, float3 bb,float value){
				return float3(mix(aa.x,bb.x,value),mix(aa.y,bb.y,value),mix(aa.z,bb.z,value));
			}

			float fract(float x){
				return x - floor(x);
			}

			float2 fract2(float2 mm){
				return float2(fract(mm.x),fract(mm.y));
			}

			float hash( float2 p ) {
				float h = dot(p,float2(127.1,311.7));	
    			return fract(sin(h)*43758.5453123);
			}

			float noise( in float2 p ) {
    			float2 i = floor( p );
   			    float2 f = fract2( p );	
				float2 u = f*f*(3.0-2.0*f);
    			return -1.0+2.0*mix( mix( hash( i + float2(0.0,0.0) ), 
                     	hash( i + float2(1.0,0.0) ), u.x),
                		mix( hash( i + float2(0.0,1.0) ), 
                     	hash( i + float2(1.0,1.0) ), u.x), u.y);
			}

			float getDiffuse(float3 n,float3 l,float p){
				return pow(dot(n,l) * 0.4 + 0.6 ,p);
			}

			float getSpecular(float3 n,float3 l,float3 e,float s){
				float nrm = (s + 8.0) / ( 3.141592 * 8.0);
				return pow(max(dot(reflect(e,n),l),0.0),s) * nrm;
			}

			// sky
			float3 getSkyColor(float3 e) {
    			e.y = max(e.y,0.0);
    			return float3(pow(1.0-e.y,2.0), 1.0-e.y, 0.6+(1.0-e.y)*0.4);
			}

			float sea_octave(float2 uv,float choopy){
				uv += noise(uv);
				float2 wv = 1.0- abs(sin(uv));
				float2 swv = abs(cos(uv));
				wv = mixVec2(wv,swv,wv);
				return pow(1.0 - pow(wv.x * wv.y,0.65),choopy);
			}

			float map(float3 p) {
    			float freq = 0.16;
    			float amp = 0.6;
    			float choppy = 4.0;
   	 			float2 uv = p.xz; 
   	 			uv.x *= 0.75;
    
   			    float d, h = 0.0;    
    			for(int i = 0; i < 3; i++) {        
    				d = sea_octave((uv+(1.0 + _Time.y * 0.8))*freq,choppy);
    				d += sea_octave((uv-(1.0 + _Time.y * 0.8))*freq,choppy);
        			h += d * amp; 
        			float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6);       
    				uv = mul(octave_m,uv); 
    				freq = freq * 1.9; 
    				amp = amp * 0.22;
        			choppy = mix(choppy,1.0,0.2);
    			}
    			return p.y - h;
			}

			float map_detailed(float3 p) {
    			float freq = 0.16;
    			float amp = 0.6;
    			float choppy = 4.0;
   	 			float2 uv = p.xz; 
   	 			uv.x *= 0.75;
    
    			float d, h = 0.0;    
    			for(int i = 0; i < 5; i++) {        
    				d = sea_octave((uv+(1.0 + _Time.y * 0.8))*freq,choppy);
    				d += sea_octave((uv-(1.0 + _Time.y * 0.8))*freq,choppy);
        			h += d * amp;        
        			float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.6);
    				uv = mul(octave_m,uv); 
    				freq = freq * 1.9; 
    				amp = amp * 0.22;
        			choppy = mix(choppy,1.0,0.2);
    			}
    			return p.y - h;
			}

		
			float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist) {
				float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
				fresnel = pow(fresnel, 3.0) * 0.5;

				float3 reflected = getSkyColor(reflect(eye, n));
				float3 refracted = float3(0.1,0.19,0.22) + getDiffuse(n, l, 80.0) * float3(0.8,0.9,0.6) * 0.12;

				float3 color = mixVec3(refracted, reflected, fresnel);

				float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
				color += float3(0.8,0.9,0.6) * (p.y - 0.7) * 0.18 * atten;

				float specularPart = getSpecular(n, l, eye, 60.0); 
				color += float3(specularPart,specularPart,specularPart);

				return color;
			}

			float3 getNormal(float3 p, float eps) {
    			float3 n;
    			n.y = map_detailed(p);    
    			n.x = map_detailed(float3(p.x+eps,p.y,p.z)) - n.y;
    			n.z = map_detailed(float3(p.x,p.y,p.z+eps)) - n.y;
    			n.y = eps;
    			return normalize(n);
			}

			float heightMapTracing(float3 ori, float3 dir,out float3 p) {  
    			float tm = 0.0;
    			float tx = 1000.0;    
    			float hx = map(ori + dir * tx);
    			if(hx > 0.0) 
    				return tx;   
    			float hm = map(ori + dir * tm);    
    			float tmid = 0.0;
    			for(int i = 0; i < 8; i++) {
    			    tmid = mix(tm,tx, hm/(hm-hx));                   
    			    p = ori + dir * tmid;                   
    				float hmid = map(p);
					if(hmid < 0.0) {
    			    	tx = tmid;
    			        hx = hmid;
    			    } else {
    			        tm = tmid;
    			        hm = hmid;
    			    }
    			}
    			return tmid;
			}

			float3 m_pow(float3 di,float3 mi){
				return float3(pow(di.x,mi.x),pow(di.y,mi.y),pow(di.z,mi.z));
			}
			
			//sampler2D _MainTex;

			float4 frag (v2f i) : SV_Target
			{
				float2 uv =  i.position.xy/ _ScreenParams.xy;
			 	uv.x *= _ScreenParams.x/ _ScreenParams.y ;
			 	uv = uv * 2.0 - 1.0;
			 	uv.x *= _ScreenParams.x/ _ScreenParams.y ;
			 	float time = _Time.y * 0.3 ;
			 	    
			 	// ray
			 	float3 ang = float3(sin(time*3.0)*0.1,sin(time)*0.2+0.3,time);    
			 	float3 ori = float3(0.0,3.5,time*5.0);
			 	float3 dir = normalize(float3(uv.xy,-2.0)); 
			 	dir.z += length(uv) * 0.15;
			 	dir = mul(fromEuler(ang),normalize(dir));
			 	
			 	// tracing
			 	float3 p;
			 	heightMapTracing(ori,dir,p);
			 	float3 dist = p - ori;
			 	float3 n = getNormal(p, dot(dist,dist) * (0.1 / _ScreenParams.y));
			 	float3 light = normalize(float3(0.0,1.0,0.8)); 
			 	         
			 	// color
			 	float3 color = mixVec3(
			 	    getSkyColor(dir),
			 	    getSeaColor(p,n,light,dir,dist),
			 		pow(smoothstep(0.0,-0.05,dir.y),0.3));
			 	    
			 	// post
			    float4 fragColor = float4(m_pow(color,float3(0.75,0.75,0.75)), 1.0);
			    return fragColor;
			}
			ENDCG
		}
	}
}
