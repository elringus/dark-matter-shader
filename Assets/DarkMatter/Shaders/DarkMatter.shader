Shader "DarkMatter" 
{
    Properties 
	{
        _NoiseTex ("Noise Texture (RG)", 2D) = "white" {}
        _Strength ("Distortion strength", Range(0.1, 1)) = 0.2
        _Transparency ("Transparency", Range(0.01, 0.1)) = 0.05
    }
     
    SubShader 
	{
		Tags { "Queue" = "Transparent+1" }
		
        GrabPass 
		{
            Name "BASE"
            Tags { "LightMode" = "Always" }
        }
       
        Pass 
		{
            Name "BASE"
            Tags { "LightMode" = "Always" }
            Lighting Off
            ZWrite On
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            AlphaTest Greater 0
         
			CGPROGRAM
			#pragma vertex ComputeVertex
			#pragma fragment ComputeFragment
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma fragmentoption ARB_fog_exp2
			#include "UnityCG.cginc"
 
			sampler2D _GrabTexture : register(s0);
			float4 _NoiseTex_ST;
			sampler2D _NoiseTex;
			float _Strength;
			float _Transparency;
 
			struct VertexInput 
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
 
			struct VertexOutput 
			{
				float4 position : POSITION;
				float4 screenPos : TEXCOORD0;
				float2 uvmain : TEXCOORD2;
				float distortion : TEXCOORD3;
			};
			
			fixed4 Overlay (fixed4 a, fixed4 b) 
			{
				fixed4 r = a > .5 ? 1.0 - 2.0 * (1.0 - a) * (1.0 - b) : 2.0 * a * b;
				r.a = b.a;
				return r;
			}
 
			VertexOutput ComputeVertex (VertexInput vertexInput) 
			{
				VertexOutput vertexOutput;
				
				vertexOutput.position = mul(UNITY_MATRIX_MVP, vertexInput.vertex);
				vertexOutput.uvmain = TRANSFORM_TEX(vertexInput.texcoord, _NoiseTex);
				float viewAngle = dot(normalize(ObjSpaceViewDir(vertexInput.vertex)), vertexInput.normal);
				vertexOutput.distortion = viewAngle * viewAngle; 
				float depth = -mul(UNITY_MATRIX_MV, vertexInput.vertex).z; 
				vertexOutput.distortion /= 1 + depth / 15; 
				vertexOutput.distortion *= _Strength; 
				vertexOutput.screenPos = vertexOutput.position;
				
				return vertexOutput;
			}
 
			half4 ComputeFragment (VertexOutput vertexOutput) : COLOR
			{  
				float2 screenPos = vertexOutput.screenPos.xy / vertexOutput.screenPos.w;
				screenPos.x = (screenPos.x + 1) * 0.5; 
				screenPos.y = (screenPos.y + 1) * 0.5; 
 
				// check if anti aliasing is used
				if (_ProjectionParams.x < 0)
					screenPos.y = 1 - screenPos.y;
   
				// get two offset values by looking up the noise texture shifted in different directions
				half4 offsetColor1 = tex2D(_NoiseTex, vertexOutput.uvmain + _Time.xz / 50);
				half4 offsetColor2 = tex2D(_NoiseTex, vertexOutput.uvmain - _Time.yx / 50);
   
				// use the r values from the noise texture lookups and combine them for x offset
				// use the g values from the noise texture lookups and combine them for y offset
				// use minus one to shift the texture back to the center
				// scale with distortion amount
				screenPos.x += ((offsetColor1.r + offsetColor2.r) - 1) * vertexOutput.distortion;
				screenPos.y += ((offsetColor1.g + offsetColor2.g) - 1) * vertexOutput.distortion;
   
				half4 color = tex2D(_GrabTexture, screenPos);
				color.a = vertexOutput.distortion / _Transparency;
				
				float2 grabTexcoord = vertexOutput.screenPos.xy / vertexOutput.screenPos.w; 
				grabTexcoord.x = (grabTexcoord.x + 1.0) * .5;
				grabTexcoord.y = (grabTexcoord.y + 1.0) * .5; 
				#if UNITY_UV_STARTS_AT_TOP
				grabTexcoord.y = 1.0 - grabTexcoord.y;
				#endif
				
				half4 grabColor = tex2D(_GrabTexture, grabTexcoord); 
				
				return Overlay(grabColor, color);
			}
 
			ENDCG
        }
    }
}
