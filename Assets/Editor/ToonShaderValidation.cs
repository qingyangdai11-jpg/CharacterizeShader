using System;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

// Explicit menu/batch validation only; never changes the user's open scene.
public static class ToonShaderValidation
{
    [MenuItem("Tools/CS15/Validate Toon Shaders")]
    public static void Validate()
    {
        var report = new StringBuilder();
        int errors = 0;
        foreach (string kind in new[] { "eye", "hair", "nonoutline", "skin", "standard" })
        {
            var shader = Shader.Find("CS15/toon_" + kind);
            if (!shader) { report.AppendLine(kind + ": MISSING"); errors++; continue; }
            var variants = new ShaderVariantCollection();
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ForwardBase, new string[0]));
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ForwardBase, new[] { "DIRECTIONAL", "SHADOWS_SCREEN" }));
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ForwardAdd, new[] { "POINT" }));
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ForwardAdd, new[] { "SPOT", "SHADOWS_DEPTH" }));
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ShadowCaster, new[] { "SHADOWS_DEPTH" }));
            variants.Add(new ShaderVariantCollection.ShaderVariant(shader, PassType.ShadowCaster, new[] { "SHADOWS_CUBE" }));
            variants.WarmUp();
            foreach (var message in ShaderUtil.GetShaderMessages(shader))
            {
                report.AppendLine(kind + ": " + message.severity + " " + message.message + " " + message.file + ":" + message.line);
                if (message.severity.ToString() == "Error") errors++;
            }
            if (!shader.isSupported) { errors++; report.AppendLine(kind + ": unsupported"); }
            report.AppendLine(kind + ": " + shader.passCount + " passes, supported=" + shader.isSupported);
        }
        report.AppendLine("Errors: " + errors);
        Directory.CreateDirectory("ToonValidation");
        File.WriteAllText("ToonValidation/shaders.txt", report.ToString());
        Debug.Log(report.ToString());
        if (errors != 0) throw new Exception("Toon shader validation failed. See ToonValidation/shaders.txt");
    }

    public static void Batch()
    {
        try { Validate(); RenderPreview(); RenderCharacters(); Validate(); EditorApplication.Exit(0); }
        catch (Exception e) { Debug.LogException(e); EditorApplication.Exit(1); }
    }

    static void RenderPreview()
    {
        var scene = UnityEditor.SceneManagement.EditorSceneManager.NewScene(UnityEditor.SceneManagement.NewSceneSetup.EmptyScene);
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.3f,0.3f,0.35f);
        var light = new GameObject("Directional").AddComponent<Light>();
        light.type = LightType.Directional;
        light.transform.rotation = Quaternion.Euler(25,-40,0);
        light.shadows = LightShadows.Soft;
        QualitySettings.shadows = ShadowQuality.All;
        var camera = new GameObject("Camera").AddComponent<Camera>();
        camera.transform.position = new Vector3(0,1,-9);
        camera.transform.LookAt(new Vector3(0,0,0));
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = new Color(0.16f,0.18f,0.23f);
        camera.orthographic = true;
        camera.orthographicSize = 1.5f;
        camera.renderingPath = RenderingPath.Forward;
        int index = 0;
        foreach (var kind in new[] { "eye", "hair", "nonoutline", "skin", "standard" })
        {
            var sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.transform.position = new Vector3((index++-2)*1.4f,0,0);
            var mat = new Material(Shader.Find("CS15/toon_" + kind));
            mat.SetColor("_Color",new Color(0.85f,0.55f,0.48f));
            sphere.GetComponent<Renderer>().sharedMaterial = mat;
        }
        var rt = new RenderTexture(1400,500,24);
        camera.targetTexture = rt;
        camera.Render();
        RenderTexture.active = rt;
        var image = new Texture2D(rt.width,rt.height,TextureFormat.RGB24,false);
        image.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);
        image.Apply();
        File.WriteAllBytes("ToonValidation/preview.png",image.EncodeToPNG());
        camera.targetTexture = null;
        RenderTexture.active = null;
        UnityEngine.Object.DestroyImmediate(image);
        rt.Release();
        UnityEngine.Object.DestroyImmediate(rt);
    }

    static void RenderCharacters()
    {
        string[] names = { "1_ReisalinStout", "茜特菈莉01", "茜特菈莉02" };
        for (int index = 0; index < names.Length; index++)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/CS15/Char/Prefabs/"+names[index]+".prefab");
            if (!prefab) continue;
            UnityEditor.SceneManagement.EditorSceneManager.NewScene(UnityEditor.SceneManagement.NewSceneSetup.EmptyScene);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.35f,0.35f,0.4f);
            var character = UnityEngine.Object.Instantiate(prefab);
            character.SetActive(true);
            character.transform.position = Vector3.zero;
            character.transform.rotation = Quaternion.identity;
            foreach (var animator in character.GetComponentsInChildren<Animator>()) animator.enabled = false;
            var renderers = character.GetComponentsInChildren<Renderer>();
            Bounds bounds = new Bounds();
            bool first = true;
            var materials = new StringBuilder();
            foreach (var renderer in renderers)
            {
                if (!renderer.enabled) continue;
                if (first) { bounds = renderer.bounds; first=false; } else bounds.Encapsulate(renderer.bounds);
                foreach (var mat in renderer.sharedMaterials)
                    materials.AppendLine(renderer.name+": "+(mat ? mat.name+" / "+mat.shader.name : "MISSING"));
            }
            File.WriteAllText("ToonValidation/character-"+index+"-materials.txt",materials.ToString());
            float height = Mathf.Max(bounds.size.y,0.1f);
            var light = new GameObject("Key").AddComponent<Light>();
            light.type = LightType.Directional;
            light.transform.rotation = Quaternion.Euler(35,150,0);
            light.intensity = 0.9f;
            light.shadows = LightShadows.Soft;
            var camera = new GameObject("Camera").AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.2f,0.24f,0.3f);
            camera.renderingPath = RenderingPath.Forward;
            camera.orthographic = true;
            camera.orthographicSize = height*0.56f;
            camera.nearClipPlane = height*0.01f;
            camera.farClipPlane = height*20;
            camera.transform.position = bounds.center+new Vector3(0,0,height*3);
            camera.transform.LookAt(bounds.center);
            var rt = new RenderTexture(800,1000,24);
            rt.antiAliasing = 4;
            camera.targetTexture = rt;
            camera.Render();
            RenderTexture.active = rt;
            var image = new Texture2D(rt.width,rt.height,TextureFormat.RGB24,false);
            image.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);
            image.Apply();
            File.WriteAllBytes("ToonValidation/character-"+index+".png",image.EncodeToPNG());
            if (index == 2)
            {
                // A neutral reference separates imported rig deformation from shader work.
                foreach (var renderer in renderers)
                {
                    var neutral = renderer.sharedMaterials;
                    for (int slot=0; slot<neutral.Length; slot++)
                    {
                        if (!neutral[slot]) continue;
                        var source = neutral[slot];
                        var mat = new Material(Shader.Find("Unlit/Texture"));
                        mat.mainTexture = source.mainTexture;
                        mat.mainTextureScale = source.mainTextureScale;
                        mat.mainTextureOffset = source.mainTextureOffset;
                        neutral[slot] = mat;
                    }
                    renderer.sharedMaterials = neutral;
                }
                camera.Render();
                RenderTexture.active = rt;
                image.ReadPixels(new Rect(0,0,rt.width,rt.height),0,0);
                image.Apply();
                File.WriteAllBytes("ToonValidation/character-2-unlit-reference.png",image.EncodeToPNG());
            }
            camera.targetTexture = null;
            RenderTexture.active = null;
            UnityEngine.Object.DestroyImmediate(image);
            rt.Release();
            UnityEngine.Object.DestroyImmediate(rt);
        }
    }
}
