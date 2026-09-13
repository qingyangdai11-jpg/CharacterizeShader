#ifndef CS15_TOON_COMMON
#define CS15_TOON_COMMON
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

sampler2D _MainTex, _BumpMap, _AOMap, _LightMap, _SpecMap, _DiffuseRamp;
sampler2D _TattooTex, _EmissionMap, _DecalMap;
float4 _MainTex_ST, _BumpMap_ST, _AOMap_ST, _LightMap_ST, _SpecMap_ST;
float4 _TattooTex_ST, _EmissionMap_ST, _DecalMap_ST;
UNITY_DECLARE_TEXCUBE(_EnvMap);
half4 _EnvMap_HDR;
half4 _Color, _ShadowColor, _TintLayer1, _TintLayer2, _TintLayer3;
// _SpecColor is already declared by Unity's Lighting.cginc.
half4 _RimColor, _TattooColor, _EmissionColor, _OutlineColor;
float _BumpScale, _AOIntensity, _UseLightMap, _ShadowThreshold, _ShadowSmoothness;
float _UseRamp, _TintLayer1_Offset, _TintLayer2_Offset, _TintLayer3_Offset;
float _VertexShadow, _SpecIntensity, _SpecShininess, _SpecMapStrength;
float _RimIntensity, _RimPower, _EnvIntensity, _EnvRotate, _Roughness;
float _FresnelMin, _FresnelMax, _AmbientIntensity, _ShadowStrength;
float _TattooBlend, _AlphaClip, _Cutoff, _OutlinePixels, _EnableOutline;
float _HairShift, _HairAnisotropy, _SkinWrap, _EyeBrightness, _Parallax;
float _DecalIntensity;

float3 ToonSafeNormal(float3 v) { return v * rsqrt(max(dot(v,v), 1e-8)); }
float2 ToonUV(float2 uv, float4 st) { return uv * st.xy + st.zw; }
void ToonClip(float2 uv)
{
    if (_AlphaClip > 0.5) clip(tex2D(_MainTex, ToonUV(uv, _MainTex_ST)).a * _Color.a - _Cutoff);
}
struct ToonApp
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};
#if !defined(TOON_SHADOW_PASS)
struct ToonVaryings
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float3 tangent : TEXCOORD3;
    float3 bitangent : TEXCOORD4;
    float4 color : COLOR;
    LIGHTING_COORDS(5,6)
    UNITY_FOG_COORDS(7)
};
ToonVaryings ToonVert(ToonApp v)
{
    ToonVaryings o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.normal = UnityObjectToWorldNormal(v.normal);
    o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
    o.bitangent = cross(o.normal, o.tangent) * v.tangent.w * unity_WorldTransformParams.w;
    o.color = v.color;
    TRANSFER_VERTEX_TO_FRAGMENT(o);
    UNITY_TRANSFER_FOG(o,o.pos);
    return o;
}
half4 ToonFrag(ToonVaryings i, fixed facing : VFACE) : SV_Target
{
    ToonClip(i.uv);
    float3 n0 = ToonSafeNormal(i.normal) * (facing >= 0 ? 1 : -1);
    float3 t = ToonSafeNormal(i.tangent - n0 * dot(n0,i.tangent));
    float3 b = ToonSafeNormal(i.bitangent);
    float3 v = ToonSafeNormal(UnityWorldSpaceViewDir(i.worldPos));
    float3 l = ToonSafeNormal(UnityWorldSpaceLightDir(i.worldPos));
    float3 nt = UnpackNormal(tex2D(_BumpMap,ToonUV(i.uv,_BumpMap_ST)));
    nt.xy *= _BumpScale;
    nt = ToonSafeNormal(nt);
    float3 n = ToonSafeNormal(t*nt.x + b*nt.y + n0*nt.z);
    float2 baseUV = ToonUV(i.uv,_MainTex_ST);
#if defined(TOON_EYE)
    float2 viewTS = float2(dot(v,t),dot(v,b));
    float depth = 1-smoothstep(0.2,0.5,length(baseUV-0.5));
    baseUV += clamp(viewTS / max(abs(dot(v,n0)),0.25),-2,2) * _Parallax * depth;
#endif
    half4 base = tex2D(_MainTex,baseUV) * _Color;
    half4 tattoo = tex2D(_TattooTex,ToonUV(i.uv,_TattooTex_ST));
    base.rgb = lerp(base.rgb,tattoo.rgb*_TattooColor.rgb,saturate(tattoo.a*_TattooColor.a*_TattooBlend));
    float ao = lerp(1,tex2D(_AOMap,ToonUV(i.uv,_AOMap_ST)).r,_AOIntensity);
    half4 lm = tex2D(_LightMap,ToonUV(i.uv,_LightMap_ST));
    ao *= lerp(1,lm.g,_UseLightMap);
    float ndl = dot(n,l);
#if defined(TOON_SKIN)
    ndl = (ndl + _SkinWrap)/(1+_SkinWrap);
#elif defined(TOON_EYE)
    float3 irisNormal = ToonSafeNormal(-t*nt.x-b*nt.y+n0*nt.z);
    ndl = max(0,dot(irisNormal,l));
#endif
    float halfLambert = saturate(ndl*0.5+0.5 + (lm.r-0.5)*0.4*_UseLightMap);
    float shade = halfLambert * ao * lerp(1,i.color.r,_VertexShadow);
    float width = max(_ShadowSmoothness, fwidth(shade));
    float lit = smoothstep(_ShadowThreshold-width,_ShadowThreshold+width,shade);
    UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);
    float receivedShadow = lerp(1,atten,_ShadowStrength);
    float3 tint = lerp(_ShadowColor.rgb,1,lit*receivedShadow);
    if (_UseRamp > 0.5)
    {
        // Video: RGB channels encode three independently offset tint layers.
        float x = saturate(shade*receivedShadow);
        float r = tex2D(_DiffuseRamp,float2(saturate(x+_TintLayer1_Offset),0.5)).r;
        float g = tex2D(_DiffuseRamp,float2(saturate(x+_TintLayer2_Offset),0.5)).g;
        float bl = tex2D(_DiffuseRamp,float2(saturate(x+_TintLayer3_Offset),0.5)).b;
        tint = lerp(1,_TintLayer1.rgb,r*_TintLayer1.a)
             * lerp(1,_TintLayer2.rgb,g*_TintLayer2.a)
             * lerp(1,_TintLayer3.rgb,bl*_TintLayer3.a);
    }
    half4 specMap = tex2D(_SpecMap,ToonUV(i.uv,_SpecMap_ST));
    float specMask = lerp(1,specMap.r,_SpecMapStrength);
    float smoothness = lerp(1,specMap.a,_SpecMapStrength);
    float3 h = ToonSafeNormal(l+v);
    float spec = pow(saturate(dot(n,h)),max(1,_SpecShininess*smoothness));
#if defined(TOON_HAIR)
    float3 strand = ToonSafeNormal(b+n*_HairShift);
    float th = dot(strand,h);
    float anisotropic = pow(sqrt(saturate(1-th*th)),max(1,_SpecShininess*smoothness));
    spec = lerp(spec,anisotropic,_HairAnisotropy);
#endif
    // Positional main lights must fade to zero outside their range.
    float3 direct = base.rgb*tint*_LightColor0.rgb * lerp(1,atten,_WorldSpaceLightPos0.w);
    float3 highlight = spec * _SpecColor.rgb * _SpecIntensity * specMask * atten * saturate(ndl) * _LightColor0.rgb;
#if defined(TOON_ADD)
    half4 result = half4((base.rgb*lit*_LightColor0.rgb*atten + highlight),0);
    UNITY_APPLY_FOG_COLOR(i.fogCoord,result,half4(0,0,0,0));
#else
    float3 ambient = max(0,ShadeSH9(float4(n,1))) * _AmbientIntensity * ao * base.rgb;
    float rim = pow(saturate(1-dot(n,v)),max(0.1,_RimPower));
    float fresnel = smoothstep(_FresnelMin,max(_FresnelMin+0.001,_FresnelMax),1-saturate(dot(n,v)));
    float3 reflection = reflect(-v,n);
    float sine, cosine; sincos(radians(_EnvRotate),sine,cosine);
    reflection.xz = float2(cosine*reflection.x-sine*reflection.z,sine*reflection.x+cosine*reflection.z);
    half4 env = UNITY_SAMPLE_TEXCUBE_LOD(_EnvMap,reflection,saturate(_Roughness)*6);
    float3 environment = DecodeHDR(env,_EnvMap_HDR)*_EnvIntensity*fresnel*specMask;
    float3 color = direct+ambient+highlight+environment+_RimColor.rgb*rim*_RimIntensity*lit*receivedShadow;
#if defined(TOON_EYE)
    color = (direct+ambient)*_EyeBrightness+highlight+environment;
    color += tex2D(_DecalMap,ToonUV(i.uv,_DecalMap_ST)).rgb*_DecalIntensity;
#endif
    color += tex2D(_EmissionMap,ToonUV(i.uv,_EmissionMap_ST)).rgb*_EmissionColor.rgb;
    half4 result = half4(color,base.a);
    UNITY_APPLY_FOG(i.fogCoord,result);
#endif
    return result;
}
struct OutlineVaryings { float4 pos:SV_POSITION; float2 uv:TEXCOORD0; UNITY_FOG_COORDS(1) };
OutlineVaryings ToonOutlineVert(ToonApp v)
{
    OutlineVaryings o;
    o.pos = UnityObjectToClipPos(v.vertex);
    float3 vn = mul((float3x3)UNITY_MATRIX_IT_MV,v.normal);
    float2 direction = mul((float3x3)UNITY_MATRIX_P,vn).xy;
    direction *= _ScreenParams.xy;
    direction *= rsqrt(max(dot(direction,direction),1e-8));
    o.pos.xy += direction*2*_OutlinePixels/_ScreenParams.xy*o.pos.w;
    o.uv = v.uv;
    UNITY_TRANSFER_FOG(o,o.pos);
    return o;
}
half4 ToonOutlineFrag(OutlineVaryings i):SV_Target
{
    clip(_EnableOutline-0.5);
    ToonClip(i.uv);
    half4 color = _OutlineColor;
    UNITY_APPLY_FOG(i.fogCoord,color);
    return color;
}
#endif
struct ToonShadowVaryings { V2F_SHADOW_CASTER; float2 uv:TEXCOORD1; };
ToonShadowVaryings ToonShadowVert(ToonApp v)
{
    ToonShadowVaryings o; o.uv=v.uv;
    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
    return o;
}
float4 ToonShadowFrag(ToonShadowVaryings i):SV_Target
{
    ToonClip(i.uv);
    SHADOW_CASTER_FRAGMENT(i)
}
#endif
