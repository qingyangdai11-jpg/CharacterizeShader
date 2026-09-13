using UnityEngine;
using UnityEditor;
using System.IO;

[InitializeOnLoad]
public class InspectClip
{
    static InspectClip()
    {
        Inspect();
    }

    [MenuItem("Tools/Inspect Face Smile Clip")]
    public static void Inspect()
    {
        string path = "Assets/CS15/Char/Animations/Emotions/茜特菈莉_面部动画.fbx";
        Object[] objs = AssetDatabase.LoadAllAssetsAtPath(path);
        string log = "=== INSPECTING ASSETS IN " + path + " ===\n";
        foreach (var obj in objs)
        {
            if (obj is AnimationClip clip)
            {
                log += "Clip: " + clip.name + " length: " + clip.length + " isHumanMotion: " + clip.isHumanMotion + "\n";
                EditorCurveBinding[] bindings = AnimationUtility.GetCurveBindings(clip);
                log += "Total curve bindings: " + bindings.Length + "\n";
                foreach (var b in bindings)
                {
                    if (b.propertyName.Contains("blendShape") || b.propertyName.Contains("Mouth") || b.propertyName.Contains("Eye") || b.path.Contains("Face"))
                    {
                        log += "  [SK] path='" + b.path + "', type=" + b.type.Name + ", prop='" + b.propertyName + "'\n";
                    }
                }
                for (int i = 0; i < Mathf.Min(15, bindings.Length); i++)
                {
                    log += "  [Bone/Other] path='" + bindings[i].path + "', type=" + bindings[i].type.Name + ", prop='" + bindings[i].propertyName + "'\n";
                }
            }
        }
        File.WriteAllText("Assets/clip_inspect_log.txt", log);
        Debug.Log(log);
    }
}
