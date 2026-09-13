Shader "Citlali/ToonBodySkin"
{
    Properties
    {
        _Color ("Main Color", Color) = (1, 1, 1, 1)
        _MainTex ("Base Skin Texture (RGB)", 2D) = "white" {}
        
        [Header(Lightmap And Shadow)]
        _LightMap ("Lightmap (G=AO, R=Shadow Bias)", 2D) = "white" {}
        _ShadowColor ("Shadow Tint Color", Color) = (0.90, 0.75, 0.78, 1.0)
        _ShadowThreshold ("Shadow Threshold", Range(0, 1)) = 0.5
        _ShadowSmoothness ("Shadow Smoothness", Range(0.001, 0.5)) = 0.05
        
        [Header(Normal Map)]
        _BumpMap ("Normal Map (Bump)", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0, 2)) = 1.0
        
        [Header(Tattoo Overlay)]
        _TattooTex ("Tattoo Overlay (RGBA)", 2D) = "black" {}
        _TattooColor ("Tattoo Tint", Color) = (1, 1, 1, 1)
        _TattooBlend ("Tattoo Blend Intensity", Range(0, 1)) = 1.0
        
        [Header(Rim Light)]
        _RimColor ("Rim Light Color", Color) = (1.0, 0.92, 0.88, 1.0)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.0
        _RimIntensity ("Rim Intensity", Range(0, 3)) = 0.5
        
        [Header(Outline)]
        [Toggle] _EnableOutline ("Enable Outline", Float) = 1
        _OutlineColor ("Outline Color", Color) = (0.55, 0.38, 0.38, 1)
        _OutlineWidth ("Outline Width", Range(0, 0.01)) = 0.0015
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 200

        // ForwardBase Pass
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
            Cull Back
            ZWrite On
            ZTest LEqual

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _LightMap;
            float4 _LightMap_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            sampler2D _TattooTex;
            float4 _TattooTex_ST;

            fixed4 _Color;
            fixed4 _ShadowColor;
            half _ShadowThreshold;
            half _ShadowSmoothness;
            half _BumpScale;

            fixed4 _TattooColor;
            half _TattooBlend;

            fixed4 _RimColor;
            half _RimPower;
            half _RimIntensity;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldTangent : TEXCOORD2;
                float3 worldBitangent : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                float3 viewDir : TEXCOORD5;
                LIGHTING_COORDS(6, 7)
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBitangent = cross(o.worldNormal, o.worldTangent) * v.tangent.w;
                o.viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // Sample main albedo
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;

                // Sample and blend tattoo if present
                fixed4 tattoo = tex2D(_TattooTex, i.uv);
                col.rgb = lerp(col.rgb, tattoo.rgb * _TattooColor.rgb, tattoo.a * _TattooBlend);

                // Sample normal map
                float3 tNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
                tNormal.xy *= _BumpScale;
                tNormal = normalize(tNormal);
                float3x3 tbn = float3x3(i.worldTangent, i.worldBitangent, i.worldNormal);
                float3 normal = normalize(mul(tNormal, tbn));

                // Sample lightmap (G=AO, R=shadow threshold bias)
                fixed4 lm = tex2D(_LightMap, i.uv);
                float ao = lm.g;
                float shadowBias = (lm.r - 0.5) * 0.4;

                // Lighting calculation
                float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float NdotL = dot(normal, lightDir);
                
                // Shadow & Light attenuation
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                
                // Cel-shade ramp with threshold
                float halfLambert = NdotL * 0.5 + 0.5 + shadowBias;
                float ramp = smoothstep(_ShadowThreshold - _ShadowSmoothness, _ShadowThreshold + _ShadowSmoothness, halfLambert * atten);

                // Combine light and shadow colors
                fixed3 lightColor = _LightColor0.rgb;
                fixed3 ambient = ShadeSH9(float4(normal, 1.0));
                fixed3 diffuseColor = lerp(_ShadowColor.rgb, fixed3(1, 1, 1), ramp) * lightColor;

                // Rim light
                float NdotV = saturate(dot(normal, i.viewDir));
                float rim = pow(1.0 - NdotV, _RimPower) * _RimIntensity * ramp;
                fixed3 rimLight = _RimColor.rgb * rim;

                fixed3 finalRGB = (col.rgb * (diffuseColor + ambient * ao)) + rimLight;
                return fixed4(finalRGB, col.a);
            }
            ENDCG
        }

        // Outline Pass
        Pass
        {
            Name "OUTLINE"
            Tags { "LightMode"="Always" }
            Cull Front
            ZWrite On
            ZTest LEqual

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            fixed _EnableOutline;
            fixed4 _OutlineColor;
            float _OutlineWidth;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                if (_EnableOutline < 0.5)
                {
                    o.pos = float4(0, 0, 0, 0);
                    return o;
                }
                float3 norm = normalize(v.normal);
                float4 vert = v.vertex;
                vert.xyz += norm * _OutlineWidth;
                o.pos = UnityObjectToClipPos(vert);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                if (_EnableOutline < 0.5) discard;
                return _OutlineColor;
            }
            ENDCG
        }

        // Shadow Caster Pass
        UsePass "Standard/SHADOWCASTER"
    }
    FallBack "Standard"
}
