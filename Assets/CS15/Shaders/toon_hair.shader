Shader "CS15/toon_hair"
{
    Properties
    {
        [Header(Base)]
        _MainTex ("Base Map", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [Toggle] _AlphaClip ("Alpha Clip", Float) = 0
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5
        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Strength", Range(0,2)) = 1
        [Header(Toon Lighting)]
        _AOMap ("AO (R)", 2D) = "white" {}
        _AOIntensity ("AO Strength", Range(0,1)) = 1
        _LightMap ("Character Lightmap (R Bias G AO)", 2D) = "white" {}
        [Toggle] _UseLightMap ("Use Character Lightmap", Float) = 0
        _ShadowColor ("Shadow Tint", Color) = (0.72,0.65,0.75,1)
        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.5
        _ShadowSmoothness ("Shadow Softness", Range(0.001,0.3)) = 0.035
        _ShadowStrength ("Receive Shadow Strength", Range(0,1)) = 1
        _AmbientIntensity ("Ambient Strength", Range(0,2)) = 0.35
        _VertexShadow ("Vertex R Shadow Mask", Range(0,1)) = 0
        [Toggle] _UseRamp ("Use Video RGB Ramp", Float) = 0
        _DiffuseRamp ("Three Layer Ramp (RGB)", 2D) = "black" {}
        _TintLayer1 ("Tint Layer 1", Color) = (0.85,0.75,0.8,1)
        _TintLayer2 ("Tint Layer 2", Color) = (0.7,0.6,0.7,0.5)
        _TintLayer3 ("Tint Layer 3", Color) = (0.5,0.5,0.6,0)
        _TintLayer1_Offset ("Layer 1 Offset", Range(-1,1)) = 0
        _TintLayer2_Offset ("Layer 2 Offset", Range(-1,1)) = 0
        _TintLayer3_Offset ("Layer 3 Offset", Range(-1,1)) = 0
        [Header(Specular And Environment)]
        _SpecMap ("Specular (R Mask A Smoothness)", 2D) = "white" {}
        _SpecMapStrength ("Specular Map Strength", Range(0,1)) = 0
        _SpecColor ("Specular Color", Color) = (1,1,1,1)
        _SpecIntensity ("Specular Strength", Range(0,3)) = 0.6
        _SpecShininess ("Specular Exponent", Range(1,256)) = 64
        [NoScaleOffset] _EnvMap ("Environment Cubemap", Cube) = "black" {}
        _EnvIntensity ("Environment Strength", Range(0,3)) = 0
        _EnvRotate ("Environment Rotation", Range(0,360)) = 0
        _Roughness ("Reflection Roughness", Range(0,1)) = 0.3
        _FresnelMin ("Fresnel Min", Range(0,1)) = 0.2
        _FresnelMax ("Fresnel Max", Range(0,1)) = 0.9
        _RimColor ("Rim Color", Color) = (0.8,0.85,1,1)
        _RimPower ("Rim Power", Range(0.1,8)) = 4
        _RimIntensity ("Rim Strength", Range(0,2)) = 0.08
        [Header(Overlay)]
        _TattooTex ("Tattoo RGBA", 2D) = "black" {}
        _TattooColor ("Tattoo Color", Color) = (1,1,1,1)
        _TattooBlend ("Tattoo Strength", Range(0,1)) = 0
        _EmissionMap ("Emission", 2D) = "white" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,0)
        [Header(Hair)]
        _HairAnisotropy ("Anisotropic Highlight", Range(0,1)) = 0.8
        _HairShift ("Highlight Shift", Range(-1,1)) = 0.1
        [Header(Outline)]
        [Toggle] _EnableOutline ("Enable Outline", Float) = 1
        _OutlinePixels ("Outline Width (Pixels)", Range(0,5)) = 1
        _OutlineColor ("Outline Color", Color) = (0.12,0.08,0.13,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300
        Cull [_Cull]
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
            ZWrite On
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex ToonVert
            #pragma fragment ToonFrag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
#define TOON_HAIR 1
            #include "ToonCommon.cginc"
            ENDCG
        }
        Pass
        {
            Name "FORWARD_ADD"
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            ZWrite Off
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex ToonVert
            #pragma fragment ToonFrag
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
#define TOON_HAIR 1
#define TOON_ADD 1
            #include "ToonCommon.cginc"
            ENDCG
        }
        Pass
        {
            Name "OUTLINE"
            Tags { "LightMode"="Always" }
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex ToonOutlineVert
            #pragma fragment ToonOutlineFrag
            #pragma multi_compile_fog

            #include "ToonCommon.cginc"
            ENDCG
        }
        Pass
        {
            Name "SHADOWCASTER"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex ToonShadowVert
            #pragma fragment ToonShadowFrag
            #pragma multi_compile_shadowcaster
            #define TOON_SHADOW_PASS 1

            #include "ToonCommon.cginc"
            ENDCG
        }
    }
    Fallback "Transparent/Cutout/VertexLit"
}
